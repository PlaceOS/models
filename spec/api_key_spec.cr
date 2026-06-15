require "./helper"

module PlaceOS::Model
  Spec.before_each do
    Authority.clear
  end
  describe ApiKey do
    test_round_trip(ApiKey)

    describe ".saas_api_key" do
      it "checks for existing domain" do
        expect_raises(Error::InvalidSaasKey) do
          ApiKey.saas_api_key(instance_domain: "does-not-exist", instance_email: "definitely-does-not-exist")
        end
      end

      it "checks for existing email" do
        authority = Generator.authority.save!
        expect_raises(Error::InvalidSaasKey) do
          ApiKey.saas_api_key(instance_domain: authority.domain, instance_email: "does-not-exist")
        end
      end

      it "checks for an existing key for instance email on domain" do
        authority = Generator.authority.save!
        user = Generator.user(authority).save!
        key = ApiKey.new(
          name: "test",
          scopes: [UserJWT::Scope::SAAS, UserJWT::Scope::PUBLIC]
        )
        key.authority = authority
        key.user = user
        key.save!

        ApiKey
          .saas_api_key(instance_domain: authority.domain, instance_email: user.email)
          .should be_nil
      end

      it "creates a key by domain and email" do
        authority = Generator.authority.save!
        user = Generator.user(authority).save!
        token = ApiKey.saas_api_key(instance_domain: authority.domain, instance_email: user.email).not_nil!
        ApiKey.find_key!(token).should be_a(ApiKey)
      end
    end

    it "saves an API Token" do
      key = Generator.api_key.save!

      key.should_not be_nil
      key.persisted?.should be_true
      ApiKey.find!(key.id.as(String)).id.should eq key.id
      key.authority_id.should eq(key.user.not_nil!.authority_id)
    end

    it "hashes secrets on create" do
      key = Generator.api_key
      secret = key.secret
      key.secret.should eq(secret)
      key.save!
      hashed = key.secret
      hashed.should_not eq(secret)

      # ensure it's not re-hashed on save
      key.name += "bob"
      key.save!
      hashed.should eq(key.secret)
    end

    it "validates secrets" do
      key = Generator.api_key
      api_key = key.x_api_key.not_nil!
      key.save!

      found = ApiKey.find_key! api_key
      found.id.should eq(key.id)

      expect_raises(PgORM::Error::RecordNotFound) do
        fake_id = "#{key.id}.notamatch"
        ApiKey.find_key! fake_id
      end
    end

    it "returns expected JSON" do
      create = Generator.api_key
      create.save!
      created = JSON.parse(create.to_public_json).as_h
      (created["x_api_key"].as_s.size > 0).should be_true
      created.has_key?("secret").should be_false
      created["permissions"].as_s.should eq("user")

      show = ApiKey.find!(create.id.as(String))
      shown = JSON.parse(show.to_public_json).as_h
      shown.has_key?("secret").should be_false
      shown["x_api_key"].raw.nil?.should be_true

      shown["permissions"].raw.should eq("user")
    end

    it "generates a jwt object" do
      key = Generator.api_key
      key.save!
      jwt = key.build_jwt

      jwt.iss.should eq("POS")
      jwt.id.should eq(key.user_id)
      jwt.domain.should eq(key.authority.not_nil!.domain)
      jwt.scope.should eq([UserJWT::Scope.new("public")])
      jwt.public_scope?.should be_true
      user = key.user.not_nil!
      jwt.user.name.should eq(user.name)
      jwt.user.email.should contain(user.email.to_s)
      jwt.user.roles.should eq(user.groups)
      jwt.user.permissions.should eq(UserJWT::Permissions::User)

      key.permissions = UserJWT::Permissions::Admin
      jwt = key.build_jwt
      jwt.user.permissions.should eq(UserJWT::Permissions::Admin)
    end

    it "cleans up when user is deleted" do
      key = Generator.api_key
      key.save!
      id = key.id.as(String)
      ApiKey.find!(id).id.should eq key.id

      key.user.not_nil!.destroy
      ApiKey.find?(id).should be_nil
    end

    describe "expiry" do
      it "is not expired when expires_at is nil" do
        key = Generator.api_key
        key.expires_at = nil
        key.save!
        key.expired?.should be_false
      end

      it "is not expired when expires_at is in the future" do
        key = Generator.api_key
        key.expires_at = Time.utc + 1.hour
        key.save!
        key.expired?.should be_false
      end

      it "is expired when expires_at is in the past" do
        key = Generator.api_key
        key.expires_at = Time.utc - 1.hour
        expect_raises(PgORM::Error::RecordInvalid, "`expires_at` must be in the future") do
          key.save!
        end
        key.expired?.should be_true
      end

      it "converts ttl to expires_at on create" do
        key = Generator.api_key
        key.ttl = 3600
        key.save!
        key.expires_at.should_not be_nil
        key.expires_at.not_nil!.should be > Time.utc
        (key.expires_at.not_nil! - Time.utc).should be_close(3600.seconds, 5.seconds)
      end

      it "uses the sooner of expires_at and ttl" do
        key = Generator.api_key
        key.expires_at = Time.utc + 2.hours
        key.ttl = 60
        key.save!
        (key.expires_at.not_nil! - Time.utc).should be_close(60.seconds, 5.seconds)
      end

      it "includes expires_at in public JSON" do
        key = Generator.api_key
        key.expires_at = Time.utc + 1.hour
        key.save!
        json = JSON.parse(key.to_public_json).as_h
        json.has_key?("expires_at").should be_true
      end

      it "converts ttl to expires_at on create" do
        key = Generator.api_key
        key.ttl = 3600
        key.save!
        key.expires_at.should_not be_nil
        (key.expires_at.not_nil! - Time.utc).should be_close(3600.seconds, 5.seconds)
        key.ttl.should be_nil
        JSON.parse(key.to_json).as_h.has_key?("ttl").should be_false
      end

      it "round-trips with ttl from JSON input, no ttl in output" do
        authority = Generator.authority.save!
        json_input = Generator.api_key.to_json
        hash = JSON.parse(json_input).as_h
        hash["ttl"] = JSON::Any.new(3600_i64)
        key = ApiKey.from_trusted_json(hash.to_json)
        key.user = Generator.user(authority).save!
        key.save!
        key.expires_at.should_not be_nil
        json_out = JSON.parse(key.to_public_json).as_h
        json_out.has_key?("ttl").should be_false
        json_out.has_key?("expires_at").should be_true
      end
    end
  end
end
