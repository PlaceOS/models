require "./helper"

module PlaceOS::Model
  describe RateCard do
    test_round_trip(RateCard)

    Spec.before_each do
      RateCardHistory.clear
      RateCardAssignment.clear
      BookingPayment.clear
      BookingQuoteLineItem.clear
      BookingQuote.clear
      PricingRule.clear
      DurationBand.clear
      RateCard.clear
      User.clear
      Authority.clear
    end

    it "saves a valid base card" do
      card = Generator.rate_card(kind: RateCard::Kind::BASE).save!
      space = Generator.control_system.save!
      assignment = Generator.rate_card_assignment(rate_card: card, space: space).save!

      RateCard.find!(card.id.not_nil!).name.should eq card.name
      card.kind.should eq RateCard::Kind::BASE
      assignment.rate_card_id.should eq card.id
    end

    it "validates required fields" do
      card = Generator.rate_card
      card.name = ""

      card.valid?.should be_false
      card.errors.map(&.field).should contain(:name)
    end

    it "validates date range" do
      card = Generator.rate_card(
        valid_from: 3.days.from_now,
        valid_to: 1.day.from_now,
      )

      card.valid?.should be_false
      card.errors.map(&.field).should contain(:valid_to)
    end

    it "selects the most specific active base card" do
      space = Generator.control_system.save!
      site = Generator.zone.save!
      at_time = Time.utc

      site_card = Generator.rate_card(
        name: "site",
        kind: RateCard::Kind::BASE,
      ).save!
      Generator.rate_card_assignment(rate_card: site_card, site: site).save!

      winner = Generator.rate_card(
        name: "space",
        kind: RateCard::Kind::BASE,
      ).save!
      Generator.rate_card_assignment(rate_card: winner, space: space).save!

      picked = RateCard.select_base_card(space.id, site.id, at_time)
      picked.try(&.id).should eq winner.id
    end

    it "walks site ancestors for base card selection" do
      root = Generator.zone.save!
      child = Generator.zone
      child.parent_id = root.id
      child = child.save!
      leaf = Generator.zone
      leaf.parent_id = child.id
      leaf = leaf.save!

      root_card = Generator.rate_card(
        name: "root-site",
        kind: RateCard::Kind::BASE,
      ).save!
      Generator.rate_card_assignment(rate_card: root_card, site: root).save!

      winner = Generator.rate_card(
        name: "child-site",
        kind: RateCard::Kind::BASE,
      ).save!
      Generator.rate_card_assignment(rate_card: winner, site: child).save!

      picked = RateCard.select_base_card(nil, leaf.id, Time.utc)
      picked.try(&.id).should eq winner.id
    end

    it "ignores inactive and out-of-range cards during base selection" do
      space = Generator.control_system.save!
      site = Generator.zone.save!
      at_time = Time.utc

      inactive = Generator.rate_card(
        name: "inactive",
        kind: RateCard::Kind::BASE,
        active: false,
      ).save!
      Generator.rate_card_assignment(rate_card: inactive, space: space).save!

      expired = Generator.rate_card(
        name: "expired",
        kind: RateCard::Kind::BASE,
        valid_from: 10.days.ago,
        valid_to: 2.days.ago,
      ).save!
      Generator.rate_card_assignment(rate_card: expired, space: space).save!

      valid = Generator.rate_card(
        name: "valid",
        kind: RateCard::Kind::BASE,
        valid_from: 1.day.ago,
        valid_to: 1.day.from_now,
      ).save!
      Generator.rate_card_assignment(rate_card: valid, site: site).save!

      RateCard.select_base_card(space.id, site.id, at_time).try(&.id).should eq valid.id
    end

    it "returns ordered matching adjustment cards" do
      root = Generator.zone.save!
      child = Generator.zone
      child.parent_id = root.id
      child = child.save!
      leaf = Generator.zone
      leaf.parent_id = child.id
      leaf = leaf.save!

      root_card = Generator.rate_card(
        name: "root-adjust",
        kind: RateCard::Kind::ADJUSTMENT,
        priority: 10,
      ).save!
      Generator.rate_card_assignment(rate_card: root_card, site: root).save!

      child_card = Generator.rate_card(
        name: "child-adjust",
        kind: RateCard::Kind::ADJUSTMENT,
        priority: 80,
      ).save!
      Generator.rate_card_assignment(rate_card: child_card, site: child).save!

      results = RateCard.select_adjustments(nil, leaf.id, Time.utc)
      results.map(&.id).should eq [child_card.id, root_card.id]
    end

    it "records history on create/update/delete when acting_user is set" do
      actor = Generator.user.save!

      card = Generator.rate_card(name: "initial-rate")
      card.acting_user = actor
      card.save!

      card.acting_user = actor
      card.name = "renamed-rate"
      card.save!

      card.acting_user = actor
      card.destroy

      entries = RateCardHistory.for_rate_card(card.id.not_nil!)
      entries.map(&.action).should eq ["create", "update", "delete"]
      entries[1].changed_fields.should contain("name")
    end

    it "records duration band and pricing rule changes in rate card history" do
      actor = Generator.user.save!
      card = Generator.rate_card.save!

      band = Generator.duration_band(rate_card: card)
      band.acting_user = actor
      band.save!

      band.acting_user = actor
      band.name = "updated-band"
      band.save!

      band.acting_user = actor
      band.destroy

      rule = Generator.pricing_rule(rate_card: card)
      rule.acting_user = actor
      rule.save!

      rule.acting_user = actor
      rule.name = "updated-rule"
      rule.save!

      rule.acting_user = actor
      rule.destroy

      entries = RateCardHistory.for_rate_card(card.id.not_nil!)
      entries.map(&.action).should eq ["create", "update", "delete", "create", "update", "delete"]

      fields = entries.flat_map(&.changed_fields)
      fields.should contain("duration_band.name")
      fields.should contain("pricing_rule.name")
    end

    it "does not record history when acting_user is not set" do
      card = Generator.rate_card.save!
      card.name = "no-audit-update"
      card.save!
      card.destroy

      RateCardHistory.for_rate_card(card.id.not_nil!).should be_empty
    end
  end
end
