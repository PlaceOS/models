require "./helper"

module PlaceOS::Model
  describe BookingQuoteHistory do
    test_round_trip(BookingQuoteHistory)

    Spec.before_each do
      BookingQuoteHistory.clear
      BookingQuote.clear
      Booking.clear
      Tenant.clear
      RateCard.clear
      User.clear
      Authority.clear
    end

    it "saves a history entry" do
      quote = Generator.booking_quote.save!
      user = Generator.user.save!

      entry = Generator.booking_quote_history(
        quote: quote,
        user: user,
        action: "update",
        changed_fields: ["status", "total_cents"],
      ).save!

      entry.persisted?.should be_true
      entry.quote_id.should eq quote.id
      entry.user_id.should eq user.id
      entry.changed_fields.should eq ["status", "total_cents"]
      entry.created_at.should_not be_nil
    end

    it "requires quote_id, email, and action" do
      entry = BookingQuoteHistory.new(
        quote_id: UUID.random,
        email: "",
        action: "",
      )

      entry.valid?.should be_false
      fields = entry.errors.map(&.field)
      fields.should contain(:email)
      fields.should contain(:action)
    end

    it "nullifies user_id but preserves email when acting user is deleted" do
      quote = Generator.booking_quote.save!
      user = Generator.user.save!

      entry = Generator.booking_quote_history(
        quote: quote,
        user: user,
      ).save!

      entry.user_deleted?.should be_false
      user.destroy

      reloaded = BookingQuoteHistory.find!(entry.id.not_nil!)
      reloaded.user_id.should be_nil
      reloaded.email.should eq user.email.to_s
      reloaded.user_deleted?.should be_true
    end

    it "filters entries for a specific quote" do
      first = Generator.booking_quote.save!
      second = Generator.booking_quote.save!

      one = Generator.booking_quote_history(quote: first, action: "create").save!
      two = Generator.booking_quote_history(quote: first, action: "update").save!
      Generator.booking_quote_history(quote: second, action: "update").save!

      found = BookingQuoteHistory.for_quote(first.id.not_nil!)
      found.map(&.id).should eq [one.id, two.id]
    end
  end
end
