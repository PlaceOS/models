require "./helper"

module PlaceOS::Model
  describe RateCardHistory do
    test_round_trip(RateCardHistory)

    Spec.before_each do
      RateCardHistory.clear
      RateCard.clear
      User.clear
      Authority.clear
    end

    it "saves a history entry" do
      card = Generator.rate_card.save!
      user = Generator.user.save!

      entry = Generator.rate_card_history(
        rate_card: card,
        user: user,
        action: "update",
        changed_fields: ["name", "active"],
      ).save!

      entry.persisted?.should be_true
      entry.rate_card_id.should eq card.id
      entry.user_id.should eq user.id
      entry.changed_fields.should eq ["name", "active"]
      entry.created_at.should_not be_nil
    end

    it "requires rate_card_id, email, and action" do
      entry = RateCardHistory.new(
        rate_card_id: UUID.random,
        email: "",
        action: "",
      )

      entry.valid?.should be_false
      fields = entry.errors.map(&.field)
      fields.should contain(:email)
      fields.should contain(:action)
    end

    it "nullifies user_id but preserves email when acting user is deleted" do
      card = Generator.rate_card.save!
      user = Generator.user.save!

      entry = Generator.rate_card_history(
        rate_card: card,
        user: user,
      ).save!

      entry.user_deleted?.should be_false
      user.destroy

      reloaded = RateCardHistory.find!(entry.id.not_nil!)
      reloaded.user_id.should be_nil
      reloaded.email.should eq user.email.to_s
      reloaded.user_deleted?.should be_true
    end

    it "filters entries for a specific rate card" do
      first = Generator.rate_card.save!
      second = Generator.rate_card.save!

      one = Generator.rate_card_history(rate_card: first, action: "create").save!
      two = Generator.rate_card_history(rate_card: first, action: "update").save!
      Generator.rate_card_history(rate_card: second, action: "update").save!

      found = RateCardHistory.for_rate_card(first.id.not_nil!)
      found.map(&.id).should eq [one.id, two.id]
    end
  end
end
