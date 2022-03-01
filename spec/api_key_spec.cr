require "./helper"

module PlaceOS::Model
  describe ApiKey do
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

      expect_raises(RethinkORM::Error::DocumentNotFound) do
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
      ApiKey.find(id).should be_nil
    end
  end
end
