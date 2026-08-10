require "./helper"

module PlaceOS::Model
  describe Shortener do
    Spec.before_each do
      Shortener.clear
    end

    test_round_trip(Shortener)

    it "works with enabled flag and valid time periods" do
      short = Generator.shortener
      short.save!

      short.id.as(String).starts_with?("uri-").should be_true
      short.perform_redirect?.should be_true

      short.enabled = false
      short.perform_redirect?.should be_false

      short.enabled = true
      short.valid_from = 5.minutes.from_now
      short.perform_redirect?.should be_false

      short.valid_from = 5.minutes.ago
      short.perform_redirect?.should be_true

      short.valid_until = 5.minutes.from_now
      short.perform_redirect?.should be_true

      short.valid_until = 5.minutes.ago
      short.perform_redirect?.should be_false

      short.redirect_count.should eq 0
      short.increment_redirect_count
      check = Shortener.find!(short.id.as(String))
      check.redirect_count.should eq 1
    end

    it "retries id generation when same-second creates collide" do
      # `short_id` packs the creation second into the id, leaving only 63
      # possible ids per wall-clock second. Freezing time pins the timestamp
      # component, so 16 creates draw from the same 63 ids and at least one
      # collision is near-certain (~88%) — probabilistic rather than
      # deterministic (rand is deliberately not stubbed), but the retry has
      # to absorb collisions for all 16 to save successfully either way.
      user = Generator.user.save!
      authority = Generator.authority("http://collision.example.com").save!

      shorteners = Timecop.freeze(Time.utc) do
        Array.new(16) { Generator.shortener(user: user, authority: authority).save! }
      end

      shorteners.each { |short| short.persisted?.should be_true }
      Shortener.count.should eq 16

      ids = shorteners.map(&.id.as(String))
      ids.uniq.size.should eq 16

      # the compact public id format is unchanged: "uri-" + base62
      ids.each do |id|
        id.should start_with("uri-")
        id.lchop("uri-").matches?(/\A[0-9a-zA-Z]+\z/).should be_true
      end
    end
  end
end
