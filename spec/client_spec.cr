require "./helper"

module PlaceOS::Model
  describe Client do
    Spec.before_each do
      ControlSystem.clear
      Zone.clear
      Authority.clear
      Client.clear
      Partner.clear
    end

    it "saves a partnered client with partner-pays default" do
      partner = Generator.partner.save!
      client = Generator.client(partner: partner).save!
      client.persisted?.should be_true
      client.payer.should eq Client::PAYER_PARTNER
      client.client_owned?.should be_false
      client.partner.try(&.id).should eq partner.id
    end

    it "normalizes a client-owned client to pay for itself" do
      client = Generator.client.save!
      client.partner_id.should be_nil
      client.payer.should eq Client::PAYER_CLIENT
      client.client_owned?.should be_true
    end

    it "rejects an unknown payer" do
      client = Generator.client(partner: Generator.partner.save!, payer: "nobody")
      client.valid?.should be_false
      client.errors.map(&.field).should contain(:payer)
    end

    it "scopes client name uniqueness to the partner" do
      partner_a = Generator.partner.save!
      partner_b = Generator.partner.save!
      original = Generator.client(partner: partner_a).save!

      # Same name under a different partner is fine
      sibling = Generator.client(partner: partner_b)
      sibling.name = original.name
      sibling.valid?.should be_true

      # Same name under the same partner is not
      duplicate = Generator.client(partner: partner_a)
      duplicate.name = original.name
      duplicate.valid?.should be_false
      duplicate.errors.map(&.field).should contain(:name)
    end

    it "rejects duplicate names among client-owned clients" do
      original = Generator.client.save!
      duplicate = Generator.client
      duplicate.name = original.name
      duplicate.valid?.should be_false
      duplicate.errors.map(&.field).should contain(:name)
    end

    it "owns authorities via authority.client_id" do
      client = Generator.client.save!
      authority = Generator.authority(domain: "client-spec.example.com")
      authority.client_id = client.id
      authority.save!

      authority.client.try(&.id).should eq client.id
      client.authorities.to_a.map(&.id).should eq [authority.id]
    end

    it "refuses to delete a client that still owns a domain" do
      client = Generator.client.save!
      authority = Generator.authority(domain: "client-restrict.example.com")
      authority.client_id = client.id
      authority.save!

      expect_raises(Exception, /foreign key/) { client.destroy }
      Client.find?(client.id.not_nil!).should_not be_nil
    end

    it "rejects renaming a client onto a sibling's name" do
      partner = Generator.partner.save!
      original = Generator.client(partner: partner).save!
      sibling = Generator.client(partner: partner).save!

      sibling.name = original.name
      sibling.valid?.should be_false
      sibling.errors.map(&.field).should contain(:name)
    end

    it "records client ownership on zones and systems" do
      client = Generator.client.save!
      zone = Generator.zone
      zone.client_id = client.id
      zone.save!

      sys = Generator.control_system
      sys.client_id = client.id
      sys.save!

      Zone.find!(zone.id.not_nil!).client.try(&.id).should eq client.id
      ControlSystem.find!(sys.id.not_nil!).client.try(&.id).should eq client.id
    end
  end
end
