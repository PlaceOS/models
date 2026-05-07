require "./helper"

module PlaceOS::Model
  describe BookingQuoteLineItem do
    test_round_trip(BookingQuoteLineItem)

    Spec.before_each do
      BookingPayment.clear
      BookingQuoteLineItem.clear
      BookingQuote.clear
      PricingRule.clear
      DurationBand.clear
      RateCard.clear
      Attendee.clear
      Guest.clear
      Booking.clear
      Tenant.clear
    end

    it "saves and links to quote, pricing rule, and rate card assignment" do
      card = Generator.rate_card.save!
      rule = Generator.pricing_rule(rate_card: card).save!
      assignment = Generator.rate_card_assignment(
        rate_card: card,
        space: Generator.control_system.save!
      ).save!
      quote = Generator.booking_quote(rate_card: card).save!

      item = Generator.booking_quote_line_item(
        quote: quote,
        pricing_rule: rule,
        rate_card_assignment: assignment,
        charge_category: PricingRule::ChargeCategory::ASSET_HIRE,
        charge_basis: PricingRule::ChargeBasis::PER_BOOKING,
      ).save!

      found = BookingQuoteLineItem.find!(item.id.not_nil!)
      found.quote_id.should eq quote.id
      found.booking_id.should eq quote.booking_id
      found.pricing_rule_id.should eq rule.id
      found.rate_card_assignment_id.should eq assignment.id
      found.charge_category.should eq PricingRule::ChargeCategory::ASSET_HIRE
      found.charge_basis.should eq PricingRule::ChargeBasis::PER_BOOKING
    end

    it "defaults approved to false" do
      item = Generator.booking_quote_line_item
      item.approved.should be_false
      item.deleted.should be_false
    end

    it "marks a line item deleted and unapproved when its linked booking is deleted" do
      tenant = Generator.tenant.save!
      parent_booking = Generator.booking(tenant.id, "asset-parent", 1.hour.from_now, 2.hours.from_now).save!
      sub_booking = Generator.booking(tenant.id, "asset-sub", 1.hour.from_now, 2.hours.from_now).save!
      quote = Generator.booking_quote(booking: parent_booking).save!

      item = Generator.booking_quote_line_item(
        quote: quote,
        booking: sub_booking,
        approved: true,
      ).save!

      sub_booking.destroy
      item.reload!

      item.booking_id.should be_nil
      item.approved.should be_false
      item.deleted.should be_true
    end

    it "marks a line item deleted and unapproved when its linked booking is soft deleted" do
      tenant = Generator.tenant.save!
      parent_booking = Generator.booking(tenant.id, "asset-parent", 1.hour.from_now, 2.hours.from_now).save!
      sub_booking = Generator.booking(tenant.id, "asset-sub", 1.hour.from_now, 2.hours.from_now).save!
      quote = Generator.booking_quote(booking: parent_booking).save!

      item = Generator.booking_quote_line_item(
        quote: quote,
        booking: sub_booking,
        approved: true,
      ).save!

      sub_booking.deleted = true
      sub_booking.deleted_at = Time.utc.to_unix
      sub_booking.save!
      item.reload!

      item.booking_id.should eq sub_booking.id
      item.approved.should be_false
      item.deleted.should be_true
    end

    it "validates required fields" do
      item = Generator.booking_quote_line_item
      item.description = ""

      item.valid?.should be_false
      item.errors.map(&.field).should contain(:description)
    end

    it "validates quantity" do
      item = Generator.booking_quote_line_item(quantity: -0.5)
      item.valid?.should be_false
      item.errors.map(&.field).should contain(:quantity)
    end
  end
end
