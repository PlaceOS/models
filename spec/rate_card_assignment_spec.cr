require "./helper"

module PlaceOS::Model
  describe RateCardAssignment do
    test_round_trip(RateCardAssignment)

    Spec.before_each do
      RateCardHistory.clear
      RateCardAssignment.clear
      RateCard.clear
      Asset.clear
      AssetType.clear
      AssetCategory.clear
      AssetPurchaseOrder.clear
      ControlSystem.clear
      Zone.clear
      User.clear
      Authority.clear
    end

    it "saves a space assignment" do
      card = Generator.rate_card.save!
      space = Generator.control_system.save!

      assignment = Generator.rate_card_assignment(rate_card: card, space: space).save!
      assignment.rate_card_id.should eq card.id
      assignment.space_id.should eq space.id
    end

    it "saves an asset assignment" do
      card = Generator.rate_card.save!
      asset = Generator.asset.save!

      assignment = Generator.rate_card_assignment(rate_card: card, asset: asset).save!
      assignment.asset_id.should eq asset.id
      assignment.site_id.should be_nil
      assignment.space_id.should be_nil
      assignment.asset_type_id.should be_nil
    end

    it "requires exactly one target" do
      card = Generator.rate_card.save!
      space = Generator.control_system.save!
      site = Generator.zone.save!

      none = RateCardAssignment.new(rate_card_id: card.id.not_nil!)
      none.valid?.should be_false

      many = Generator.rate_card_assignment(rate_card: card, space: space, site: site)
      many.valid?.should be_false
    end

    it "enforces uniqueness per rate card and target" do
      card = Generator.rate_card.save!
      space = Generator.control_system.save!
      Generator.rate_card_assignment(rate_card: card, space: space).save!

      expect_raises(::PgORM::Error) do
        Generator.rate_card_assignment(rate_card: card, space: space).save!
      end
    end

    it "records history for assignment changes when acting_user is set" do
      actor = Generator.user.save!
      card = Generator.rate_card.save!
      site = Generator.zone.save!

      assignment = Generator.rate_card_assignment(rate_card: card, site: site)
      assignment.acting_user = actor
      assignment.save!

      assignment.acting_user = actor
      assignment.site_id = nil
      assignment.space_id = Generator.control_system.save!.id
      assignment.save!

      assignment.acting_user = actor
      assignment.destroy

      entries = RateCardHistory.for_rate_card(card.id.not_nil!)
      entries.map(&.action).should eq ["create", "update", "delete"]
      entries.flat_map(&.changed_fields).should contain("rate_card_assignment.space_id")
    end
  end
end
