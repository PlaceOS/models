require "./helper"

module PlaceOS::Model
  describe BookingPayment do
    test_round_trip(BookingPayment)

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

    it "saves and links to quote and booking" do
      quote = Generator.booking_quote.save!
      booking = quote.booking

      payment = Generator.booking_payment(
        quote: quote,
        booking: booking,
        status: BookingPayment::PaymentStatus::CAPTURED,
        payment_method: BookingPayment::PaymentMethod::CARD,
        paid_at: Time.utc,
      ).save!

      found = BookingPayment.find!(payment.id.not_nil!)
      found.quote_id.should eq quote.id
      found.booking_id.should eq booking.id
      found.status.should eq BookingPayment::PaymentStatus::CAPTURED
      found.payment_method.should eq BookingPayment::PaymentMethod::CARD
      found.booking.try(&.id).should eq booking.id
    end

    it "validates non-negative amount" do
      payment = Generator.booking_payment(amount_cents: -1)

      payment.valid?.should be_false
      payment.errors.map(&.field).should contain(:amount_cents)
    end

    it "accepts all status and payment method values" do
      BookingPayment::PaymentStatus.values.each do |status|
        BookingPayment::PaymentMethod.values.each do |method|
          payment = Generator.booking_payment(status: status, payment_method: method, reference: nil)
          payment.valid?.should be_true
        end
      end
    end

    it "enforces unique non-null references" do
      quote = Generator.booking_quote.save!
      booking = quote.booking
      ref = "provider-ref-#{RANDOM.hex(6)}"

      Generator.booking_payment(
        quote: quote,
        booking: booking,
        reference: ref,
      ).save!

      expect_raises(::PgORM::Error) do
        Generator.booking_payment(
          quote: quote,
          booking: booking,
          reference: ref,
          payment_method: BookingPayment::PaymentMethod::ONLINE,
        ).save!
      end
    end
  end
end
