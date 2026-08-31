require "./helper"
require "uuid"

module PlaceOS::Model
  describe SignageAIProvider do
    Spec.before_each do
      SignageAIJob.clear
      SignageAIProvider.clear
    end

    test_round_trip(SignageAIProvider)

    it "encrypts credentials and keeps them out of as_json" do
      authority = Generator.localhost_authority
      secret = %({"api_key":"sk-not-a-real-key"})
      row = Generator.signage_ai_provider(authority: authority, credentials: secret).save!

      row.credentials_encrypted?.should be_true
      row.credentials.should_not contain "sk-not-a-real-key"

      found = SignageAIProvider.find!(row.id.as(UUID))
      found.decrypt_credentials.should eq secret
      found.credentials_json["api_key"].as_s.should eq "sk-not-a-real-key"

      rendered = found.as_json.to_json
      rendered.should_not contain "sk-not-a-real-key"
      rendered.should_not contain "credentials"
      rendered.should contain found.name
    end

    it "does not double encrypt on repeated saves" do
      row = Generator.signage_ai_provider(credentials: %({"api_key":"one"})).save!
      ciphertext = row.credentials
      row.name = "renamed"
      row.save!
      row.credentials.should eq ciphertext
      SignageAIProvider.find!(row.id.as(UUID)).credentials_json["api_key"].as_s.should eq "one"
    end

    it "keeps one default per authority and leaves other authorities alone" do
      authority = Generator.localhost_authority
      other = Generator.authority(domain: "http://default-#{UUID.random}.test").save!

      first = Generator.signage_ai_provider(authority: authority, is_default: true).save!
      elsewhere = Generator.signage_ai_provider(authority: other, is_default: true).save!
      second = Generator.signage_ai_provider(authority: authority, is_default: true).save!

      SignageAIProvider.find!(first.id.as(UUID)).is_default.should be_false
      SignageAIProvider.find!(second.id.as(UUID)).is_default.should be_true
      SignageAIProvider.find!(elsewhere.id.as(UUID)).is_default.should be_true
    end

    it "falls back to the shared row when a domain has none" do
      authority = Generator.localhost_authority
      shared = Generator.signage_ai_provider(authority: nil, is_default: true).save!

      SignageAIProvider.default_for(authority.id.as(String)).try(&.id).should eq shared.id

      own = Generator.signage_ai_provider(authority: authority, is_default: true).save!
      SignageAIProvider.default_for(authority.id.as(String)).try(&.id).should eq own.id

      available = SignageAIProvider.available_for(authority.id.as(String)).map(&.id)
      available.should contain own.id
      available.should contain shared.id
    end

    it "ignores disabled rows when picking a default" do
      authority = Generator.localhost_authority
      Generator.signage_ai_provider(authority: authority, is_default: true, enabled: false).save!
      shared = Generator.signage_ai_provider(authority: nil).save!

      SignageAIProvider.default_for(authority.id.as(String)).try(&.id).should eq shared.id
    end

    it "reads quotas" do
      row = Generator.signage_ai_provider(quotas: {"user_per_day" => JSON::Any.new(12_i64)}).save!
      SignageAIProvider.find!(row.id.as(UUID)).quota("user_per_day").should eq 12
      row.quota("domain_per_month").should be_nil
    end
  end
end
