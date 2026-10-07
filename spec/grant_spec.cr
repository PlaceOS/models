require "./helper"

# Build partner -> org -> authority -> user, returning all four.
private def build_estate(payer = PlaceOS::Model::Organisation::PAYER_PARTNER)
  partner = PlaceOS::Model::Generator.partner.save!
  org = PlaceOS::Model::Generator.organisation(partner: partner, payer: payer).save!
  authority = PlaceOS::Model::Generator.authority(domain: "grant-#{RANDOM.hex(4)}.example.com")
  authority.organisation_id = org.id
  authority.save!
  user = PlaceOS::Model::Generator.user(authority: authority).save!
  {partner, org, authority, user}
end

module PlaceOS::Model
  describe Grant do
    Spec.before_each do
      Grant.clear
      Authority.clear
      User.clear
      Organisation.clear
      Partner.clear
    end

    it "saves a grant with a permission bitmask" do
      _, org, _, user = build_estate
      grant = Generator.grant(user, Grant::SCOPE_ORGANISATION, org.id.not_nil!.to_s, Permissions::Manage).save!
      grant.persisted?.should be_true
      grant.permission_flags.should eq Permissions::Manage
    end

    it "rejects an unknown scope_type" do
      _, _, _, user = build_estate
      grant = Generator.grant(user, "galaxy", "scope-1")
      grant.valid?.should be_false
      grant.errors.map(&.field).should contain(:scope_type)
    end

    it "resolves an authority-scope grant" do
      _, _, authority, user = build_estate
      Generator.grant(user, Grant::SCOPE_AUTHORITY, authority.id.not_nil!, Permissions::Update).save!
      Grant.resolve(user.id.not_nil!, authority).should eq Permissions::Update
    end

    it "resolves a org-scope grant onto the org's authority" do
      _, org, authority, user = build_estate
      Generator.grant(user, Grant::SCOPE_ORGANISATION, org.id.not_nil!.to_s, Permissions::Operate).save!
      Grant.resolve(user.id.not_nil!, authority).should eq Permissions::Operate
    end

    it "resolves a partner-scope grant onto every authority under that partner (decision b)" do
      partner = Generator.partner.save!
      client_a = Generator.organisation(partner: partner).save!
      client_b = Generator.organisation(partner: partner).save!
      auth_a = Generator.authority(domain: "a-#{RANDOM.hex(4)}.example.com")
      auth_a.organisation_id = client_a.id
      auth_a.save!
      auth_b = Generator.authority(domain: "b-#{RANDOM.hex(4)}.example.com")
      auth_b.organisation_id = client_b.id
      auth_b.save!
      staff = Generator.user(authority: auth_a).save!

      # One grant at partner scope reaches both clients' authorities.
      Generator.grant(staff, Grant::SCOPE_PARTNER, partner.id.not_nil!.to_s, Permissions::Manage).save!
      Grant.resolve(staff.id.not_nil!, auth_a).should eq Permissions::Manage
      Grant.resolve(staff.id.not_nil!, auth_b).should eq Permissions::Manage
    end

    it "ORs permissions across scopes on the chain" do
      partner, org, authority, user = build_estate
      Generator.grant(user, Grant::SCOPE_PARTNER, partner.id.not_nil!.to_s, Permissions::Read).save!
      Generator.grant(user, Grant::SCOPE_ORGANISATION, org.id.not_nil!.to_s, Permissions::Update).save!
      Grant.resolve(user.id.not_nil!, authority).should eq(Permissions::Read | Permissions::Update)
    end

    it "does not leak a grant into a different partner's estate" do
      _, _, authority_one, user = build_estate
      # A second, unrelated estate.
      _, _, authority_two, _ = build_estate
      Generator.grant(user, Grant::SCOPE_AUTHORITY, authority_one.id.not_nil!, Permissions::Manage).save!
      Grant.resolve(user.id.not_nil!, authority_two).should eq Permissions::None
    end

    it "ignores expired grants" do
      _, org, authority, user = build_estate
      Generator.grant(user, Grant::SCOPE_ORGANISATION, org.id.not_nil!.to_s, Permissions::Manage,
        expires_at: Time.utc - 1.hour).save!
      Grant.resolve(user.id.not_nil!, authority).should eq Permissions::None
    end

    it "honours a future expiry" do
      _, org, authority, user = build_estate
      Generator.grant(user, Grant::SCOPE_ORGANISATION, org.id.not_nil!.to_s, Permissions::Read,
        expires_at: Time.utc + 1.hour).save!
      Grant.resolve(user.id.not_nil!, authority).should eq Permissions::Read
    end

    it "returns None for a resource with no matching grant" do
      _, _, authority, user = build_estate
      Grant.resolve(user.id.not_nil!, authority).should eq Permissions::None
    end

    it "cascades on user delete" do
      _, org, _, user = build_estate
      grant = Generator.grant(user, Grant::SCOPE_ORGANISATION, org.id.not_nil!.to_s).save!
      user.destroy
      Grant.find?(grant.id.not_nil!).should be_nil
    end
  end
end
