require "./helper"

module PlaceOS::Model
  describe BookingQuote do
    test_round_trip(BookingQuote)

    Spec.before_each do
      BookingQuoteHistory.clear
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
      User.clear
      Authority.clear
    end

    it "saves and links to booking and rate card" do
      tenant = Generator.tenant.save!
      booking = Generator.booking(tenant.id, "asset-1", 1.hour.from_now, 2.hours.from_now).save!
      rate_card = Generator.rate_card.save!

      quote = Generator.booking_quote(
        booking: booking,
        rate_card: rate_card,
        status: BookingQuote::QuoteStatus::ACCEPTED,
        accepted_at: Time.utc,
      ).save!

      found = BookingQuote.find!(quote.id.not_nil!)
      found.booking_id.should eq booking.id
      found.rate_card_id.should eq rate_card.id
      found.status.should eq BookingQuote::QuoteStatus::ACCEPTED
      found.booking.try(&.id).should eq booking.id
    end

    it "has expected defaults" do
      quote = Generator.booking_quote
      quote.status.should eq BookingQuote::QuoteStatus::DRAFT
      quote.subtotal_cents.should eq 10_000
      quote.tax_cents.should eq 1_000
      quote.total_cents.should eq 11_000
      quote.currency.should eq "AUD"
    end

    it "validates non-negative amounts" do
      quote = Generator.booking_quote(subtotal_cents: -1)
      quote.valid?.should be_false
      quote.errors.map(&.field).should contain(:subtotal_cents)

      quote = Generator.booking_quote(tax_cents: -1)
      quote.valid?.should be_false
      quote.errors.map(&.field).should contain(:tax_cents)

      quote = Generator.booking_quote(total_cents: -1)
      quote.valid?.should be_false
      quote.errors.map(&.field).should contain(:total_cents)
    end

    it "accepts all quote statuses" do
      BookingQuote::QuoteStatus.values.each do |status|
        quote = Generator.booking_quote(status: status)
        quote.valid?.should be_true
      end
    end

    it "records history on create/update/delete when acting_user is set" do
      actor = Generator.user.save!
      quote = Generator.booking_quote

      quote.acting_user = actor
      quote.save!

      quote.acting_user = actor
      quote.status = BookingQuote::QuoteStatus::ACCEPTED
      quote.save!

      quote.acting_user = actor
      quote.destroy

      entries = BookingQuoteHistory.for_quote(quote.id.not_nil!)
      entries.map(&.action).should eq ["create", "update", "delete"]
      entries[1].changed_fields.should contain("status")
    end

    it "records line item and payment changes in quote history" do
      actor = Generator.user.save!
      quote = Generator.booking_quote.save!

      line_item = Generator.booking_quote_line_item(quote: quote)
      line_item.acting_user = actor
      line_item.save!

      line_item.acting_user = actor
      line_item.description = "updated-line-item"
      line_item.save!

      line_item.acting_user = actor
      line_item.destroy

      payment = Generator.booking_payment(quote: quote)
      payment.acting_user = actor
      payment.save!

      payment.acting_user = actor
      payment.amount_cents = 22_000
      payment.save!

      payment.acting_user = actor
      payment.destroy

      entries = BookingQuoteHistory.for_quote(quote.id.not_nil!)
      entries.map(&.action).should eq ["create", "update", "delete", "create", "update", "delete"]

      fields = entries.flat_map(&.changed_fields)
      fields.should contain("line_item.description")
      fields.should contain("payment.amount_cents")
    end

    it "does not record history when acting_user is not set" do
      quote = Generator.booking_quote.save!
      quote.status = BookingQuote::QuoteStatus::ACCEPTED
      quote.save!
      quote.destroy

      BookingQuoteHistory.for_quote(quote.id.not_nil!).should be_empty
    end
  end
end
