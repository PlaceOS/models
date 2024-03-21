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
  end
end
