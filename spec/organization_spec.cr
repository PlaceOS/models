require "./helper"

module PlaceOS::Model
  describe Organization do
    Spec.before_each do
      ControlSystem.clear
      Zone.clear
      Authority.clear
      Organization.clear
      Partner.clear
    end

    it "saves a partnered org with partner-pays default" do
      partner = Generator.partner.save!
      org = Generator.organization(partner: partner).save!
      org.persisted?.should be_true
      org.payer.should eq Organization::PAYER_PARTNER
      org.self_managed?.should be_false
      org.partner.try(&.id).should eq partner.id
    end

    it "normalizes a org-owned org to pay for itself" do
      org = Generator.organization.save!
      org.partner_id.should be_nil
      org.payer.should eq Organization::PAYER_ORGANIZATION
      org.self_managed?.should be_true
    end

    it "rejects an unknown payer" do
      org = Generator.organization(partner: Generator.partner.save!, payer: "nobody")
      org.valid?.should be_false
      org.errors.map(&.field).should contain(:payer)
    end

    it "scopes org name uniqueness to the partner" do
      partner_a = Generator.partner.save!
      partner_b = Generator.partner.save!
      original = Generator.organization(partner: partner_a).save!

      # Same name under a different partner is fine
      sibling = Generator.organization(partner: partner_b)
      sibling.name = original.name
      sibling.valid?.should be_true

      # Same name under the same partner is not
      duplicate = Generator.organization(partner: partner_a)
      duplicate.name = original.name
      duplicate.valid?.should be_false
      duplicate.errors.map(&.field).should contain(:name)
    end

    it "rejects duplicate names among org-owned clients" do
      original = Generator.organization.save!
      duplicate = Generator.organization
      duplicate.name = original.name
      duplicate.valid?.should be_false
      duplicate.errors.map(&.field).should contain(:name)
    end

    it "owns authorities via authority.organization_id" do
      org = Generator.organization.save!
      authority = Generator.authority(domain: "org-spec.example.com")
      authority.organization_id = org.id
      authority.save!

      authority.organization.try(&.id).should eq org.id
      org.authorities.to_a.map(&.id).should eq [authority.id]
    end

    it "refuses to delete a org that still owns a domain" do
      org = Generator.organization.save!
      authority = Generator.authority(domain: "org-restrict.example.com")
      authority.organization_id = org.id
      authority.save!

      expect_raises(Exception, /foreign key/) { org.destroy }
      Organization.find?(org.id.not_nil!).should_not be_nil
    end

    it "rejects renaming a org onto a sibling's name" do
      partner = Generator.partner.save!
      original = Generator.organization(partner: partner).save!
      sibling = Generator.organization(partner: partner).save!

      sibling.name = original.name
      sibling.valid?.should be_false
      sibling.errors.map(&.field).should contain(:name)
    end

    it "records org ownership on zones and systems" do
      org = Generator.organization.save!
      zone = Generator.zone
      zone.organization_id = org.id
      zone.save!

      sys = Generator.control_system
      sys.organization_id = org.id
      sys.save!

      Zone.find!(zone.id.not_nil!).organization.try(&.id).should eq org.id
      ControlSystem.find!(sys.id.not_nil!).organization.try(&.id).should eq org.id
    end
  end
end
