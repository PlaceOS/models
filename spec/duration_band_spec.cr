require "./helper"

module PlaceOS::Model
  describe DurationBand do
    test_round_trip(DurationBand)

    Spec.before_each do
      BookingPayment.clear
      BookingQuoteLineItem.clear
      BookingQuote.clear
      PricingRule.clear
      DurationBand.clear
      RateCard.clear
    end

    it "saves with a rate card" do
      rate_card = Generator.rate_card.save!
      band = Generator.duration_band(rate_card: rate_card).save!

      found = DurationBand.find!(band.id.not_nil!)
      found.rate_card_id.should eq rate_card.id
      found.rate_card.try(&.id).should eq rate_card.id
    end

    it "validates required fields" do
      band = Generator.duration_band
      band.name = ""

      band.valid?.should be_false
      band.errors.map(&.field).should contain(:name)
    end

    it "validates min minutes and max range" do
      band = Generator.duration_band(min_minutes: -1, max_minutes: 10)
      band.valid?.should be_false
      band.errors.map(&.field).should contain(:min_minutes)

      band = Generator.duration_band(min_minutes: 60, max_minutes: 30)
      band.valid?.should be_false
      band.errors.map(&.field).should contain(:max_minutes)
    end

    it "enforces unique name per rate card" do
      rate_card = Generator.rate_card.save!
      Generator.duration_band(rate_card: rate_card, name: "half-day").save!

      expect_raises(::PgORM::Error) do
        Generator.duration_band(rate_card: rate_card, name: "half-day").save!
      end
    end

    it "allows same name on different rate cards" do
      one = Generator.rate_card.save!
      two = Generator.rate_card.save!

      Generator.duration_band(rate_card: one, name: "full-day").save!
      Generator.duration_band(rate_card: two, name: "full-day").save!

      DurationBand.where(name: "full-day").to_a.size.should eq 2
    end
  end
end
