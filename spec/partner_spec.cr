require "./helper"

module PlaceOS::Model
  describe Partner do
    Spec.before_each do
      ControlSystem.clear
      Zone.clear
      Authority.clear
      Client.clear
      Partner.clear
    end

    it "saves a partner" do
      partner = Generator.partner.save!
      partner.persisted?.should be_true
      partner.management.should be_false
      partner.parent_id.should be_nil
    end

    it "saves a management partner" do
      partner = Generator.partner(management: true).save!
      partner.management.should be_true
    end

    it "rejects duplicate partner names" do
      existing = Generator.partner.save!
      duplicate = Generator.partner
      duplicate.name = existing.name
      duplicate.valid?.should be_false
      duplicate.errors.map(&.field).should contain(:name)
    end

    it "supports a two-tier parent chain" do
      distributor = Generator.partner.save!
      reseller = Generator.partner(parent: distributor).save!
      reseller.parent_id.should eq distributor.id
      distributor.children.to_a.map(&.id).should contain(reseller.id)
    end

    it "rejects a partner as its own parent" do
      partner = Generator.partner.save!
      partner.parent_id = partner.id
      partner.valid?.should be_false
      partner.errors.map(&.field).should contain(:parent_id)
    end

    it "rejects a cycle in the parent chain" do
      top = Generator.partner.save!
      bottom = Generator.partner(parent: top).save!
      top.parent_id = bottom.id
      top.valid?.should be_false
      top.errors.map(&.field).should contain(:parent_id)
    end

    it "lists its clients" do
      partner = Generator.partner.save!
      client = Generator.client(partner: partner).save!
      Generator.client.save!
      partner.clients.to_a.map(&.id).should eq [client.id]
    end

    it "refuses to delete a partner that still has clients" do
      partner = Generator.partner.save!
      Generator.client(partner: partner).save!

      expect_raises(Exception, /foreign key/) { partner.destroy }
      Partner.find?(partner.id.not_nil!).should_not be_nil
    end
  end
end
