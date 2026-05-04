require "./helper"

module PlaceOS::Model
  describe PricingRule do
    test_round_trip(PricingRule)

    Spec.before_each do
      BookingPayment.clear
      BookingQuoteLineItem.clear
      BookingQuote.clear
      PricingRule.clear
      DurationBand.clear
      RateCard.clear
    end

    it "saves with optional match fields" do
      card = Generator.rate_card.save!
      band = Generator.duration_band(rate_card: card).save!

      rule = Generator.pricing_rule(
        rate_card: card,
        duration_band: band,
        charge_category: PricingRule::ChargeCategory::ASSET_HIRE,
        charge_basis: PricingRule::ChargeBasis::PER_ATTENDEE,
        customer_type: PricingRule::CustomerType::EXTERNAL,
        day_type: PricingRule::DayType::WEEKEND,
        min_attendees: 10,
        max_attendees: 100,
        stackable: true,
      ).save!

      found = PricingRule.find!(rule.id.not_nil!)
      found.duration_band_id.should eq band.id
      found.customer_type.should eq "EXTERNAL"
      found.day_type.should eq "WEEKEND"
      found.stackable.should be_true
    end

    it "validates required fields" do
      card = Generator.rate_card.save!
      rule = Generator.pricing_rule(rate_card: card)
      rule.name = ""

      rule.valid?.should be_false
      rule.errors.map(&.field).should contain(:name)
    end

    it "validates attendee minimum and maximum values" do
      rule = Generator.pricing_rule(min_attendees: -1)
      rule.valid?.should be_false
      rule.errors.map(&.field).should contain(:min_attendees)

      rule = Generator.pricing_rule(max_attendees: -1)
      rule.valid?.should be_false
      rule.errors.map(&.field).should contain(:max_attendees)

      rule = Generator.pricing_rule(min_attendees: 50, max_attendees: 10)
      rule.valid?.should be_false
      rule.errors.map(&.field).should contain(:max_attendees)
    end

    it "accepts every enum value" do
      card = Generator.rate_card.save!

      PricingRule::ChargeCategory.values.each do |category|
        PricingRule::ChargeBasis.values.each do |basis|
          rule = Generator.pricing_rule(
            rate_card: card,
            charge_category: category,
            charge_basis: basis,
          )
          rule.valid?.should be_true
        end
      end
    end
  end
end
