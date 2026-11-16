require "./helper"

module PlaceOS::Model
  def self.require_reconciliation_ledger
    PgORM::Database.connection do |db|
      db.query_one("SELECT to_regclass('tenancy_reconciliations') IS NOT NULL", &.read(Bool)).should be_true
    end
  end

  def self.insert_reconciliation(actor : String, authority : String, key : String) : UUID
    PgORM::Database.connection do |db|
      db.query_one(<<-SQL, args: [actor, authority, key], &.read(UUID))
        INSERT INTO tenancy_reconciliations (actor_id, authority_id, idempotency_key, digest, plan, result)
        VALUES ($1, $2, $3, repeat('a', 64), '{"operation":"claim"}', '{"status":"applied"}')
        RETURNING id
        SQL
    end
  end

  describe "durable tenancy reconciliation ledger" do
    around_each do |example|
      PgORM::Database.transaction do |transaction|
        example.run
      ensure
        transaction.rollback unless transaction.closed?
      end
    end

    it "stores UUIDv7, the verified digest and plan/result independently of history" do
      require_reconciliation_ledger
      id = insert_reconciliation("deleted-actor", "deleted-authority", "key-#{RANDOM.hex(5)}")
      id.to_s[14].should eq '7'
      PgORM::Database.connection do |db|
        db.query_one("SELECT plan->>'operation' FROM tenancy_reconciliations WHERE id = $1", args: [id], &.read(String)).should eq "claim"
        db.query_one("SELECT result->>'status' FROM tenancy_reconciliations WHERE id = $1", args: [id], &.read(String)).should eq "applied"
        db.query_one("SELECT length(digest) FROM tenancy_reconciliations WHERE id = $1", args: [id], &.read(Int32)).should eq 64
        db.query_one("SELECT created_at IS NOT NULL FROM tenancy_reconciliations WHERE id = $1", args: [id], &.read(Bool)).should be_true
      end
    end

    it "rejects a repeated idempotency key for the same actor" do
      require_reconciliation_ledger
      key = "key-#{RANDOM.hex(5)}"
      insert_reconciliation("actor", "authority", key)
      expect_raises(PQ::PQError, /duplicate key/) do
        insert_reconciliation("actor", "authority", key)
      end
    end

    it "allows different actors to use the same idempotency key" do
      require_reconciliation_ledger
      key = "key-#{RANDOM.hex(5)}"
      first = insert_reconciliation("first-actor", "authority", key)
      second = insert_reconciliation("second-actor", "authority", key)
      first.should_not eq second
    end

    it "retains actor and authority identifiers after their source records are deleted" do
      require_reconciliation_ledger
      authority = Generator.authority("audit-#{RANDOM.hex(5)}.test").save!
      actor = Generator.user(authority: authority).save!
      id = insert_reconciliation(actor.id.as(String), authority.id.as(String), "key-#{RANDOM.hex(5)}")
      PgORM::Database.connection do |db|
        db.exec("DELETE FROM \"user\" WHERE id = $1", args: [actor.id])
        db.exec("DELETE FROM authority WHERE id = $1", args: [authority.id])
        db.query_one("SELECT actor_id FROM tenancy_reconciliations WHERE id = $1", args: [id], &.read(String)).should eq actor.id
        db.query_one("SELECT authority_id FROM tenancy_reconciliations WHERE id = $1", args: [id], &.read(String)).should eq authority.id
      end
    end
  end
end
