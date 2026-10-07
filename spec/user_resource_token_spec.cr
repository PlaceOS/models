require "http/server"

require "./helper"

module PlaceOS::Model
  # Minimal OAuth2 provider token endpoint for exercising the refresh flow
  class MockTokenServer
    getter requests = [] of URI::Params
    property response_status = HTTP::Status::OK
    property response_body = %({"access_token": "new-access", "token_type": "Bearer", "expires_in": 3600, "refresh_token": "new-refresh"})

    getter port : Int32

    def initialize
      @server = HTTP::Server.new do |context|
        @requests << URI::Params.parse(context.request.body.try(&.gets_to_end) || "")
        context.response.status = response_status
        context.response.content_type = "application/json"
        context.response.print response_body
      end
      @port = @server.bind_tcp("127.0.0.1", 0).port
      spawn { @server.listen }
      Fiber.yield
    end

    def close
      @server.close
    end
  end

  describe "User#resource_token" do
    server = uninitialized MockTokenServer
    authority = uninitialized Authority

    Spec.before_each do
      server = MockTokenServer.new
      authority = Generator.authority(domain: "http://resource-token.#{RANDOM.hex(4)}.dev").save!
      strategy = Generator.oauth_strat(authority)
      strategy.site = "http://127.0.0.1:#{server.port}"
      strategy.token_url = "/oauth/token"
      strategy.save!
    end

    Spec.after_each do
      server.close
    end

    it "returns a non-expiring access token as is" do
      user = Generator.user(authority)
      user.access_token = "stored-access"
      user.expires = false
      user.save!

      token = user.resource_token(authority)
      token.token.should eq "stored-access"
      token.expires.should be_nil
      server.requests.should be_empty
    end

    it "returns an access token that is not close to expiry" do
      expiry = 1.hour.from_now.to_unix
      user = Generator.user(authority)
      user.access_token = "stored-access"
      user.expires = true
      user.expires_at = expiry
      user.save!

      token = user.resource_token(authority)
      token.token.should eq "stored-access"
      token.expires.should eq expiry
      server.requests.should be_empty
    end

    it "defaults to the user's authority" do
      user = Generator.user(authority)
      user.access_token = "stored-access"
      user.save!

      user.resource_token.token.should eq "stored-access"
    end

    it "refreshes and saves a token that is close to expiry" do
      user = Generator.user(authority)
      user.access_token = "stored-access"
      user.refresh_token = "stored-refresh"
      user.expires = true
      user.expires_at = 2.minutes.from_now.to_unix
      user.save!

      token = user.resource_token(authority)
      token.token.should eq "new-access"
      expires = token.expires.not_nil!
      expires.should be_close(1.hour.from_now.to_unix, 10)

      server.requests.size.should eq 1
      server.requests.first["grant_type"].should eq "refresh_token"
      server.requests.first["refresh_token"].should eq "stored-refresh"

      saved = User.find!(user.id.as(String))
      saved.access_token.should eq "new-access"
      saved.refresh_token.should eq "new-refresh"
      saved.expires_at.should eq expires
    end

    it "refreshes when there is no stored access token" do
      user = Generator.user(authority)
      user.refresh_token = "stored-refresh"
      user.expires = true
      user.save!

      user.resource_token(authority).token.should eq "new-access"
    end

    it "keeps the existing refresh token when the provider doesn't rotate it" do
      server.response_body = %({"access_token": "new-access", "token_type": "Bearer", "expires_in": 3600})
      user = Generator.user(authority)
      user.refresh_token = "stored-refresh"
      user.expires = true
      user.save!

      user.resource_token(authority)
      User.find!(user.id.as(String)).refresh_token.should eq "stored-refresh"
    end

    it "uses the authority's configured oauth strategy" do
      other = MockTokenServer.new
      begin
        other.response_body = %({"access_token": "configured-access", "token_type": "Bearer", "expires_in": 3600})
        configured = Generator.oauth_strat(authority)
        configured.site = "http://127.0.0.1:#{other.port}"
        configured.save!
        authority.internals["oauth-strategy"] = JSON::Any.new(configured.id.as(String))
        authority.save!

        user = Generator.user(authority)
        user.refresh_token = "stored-refresh"
        user.expires = true
        user.save!

        user.resource_token(authority).token.should eq "configured-access"
        server.requests.should be_empty
      ensure
        other.close
      end
    end

    it "falls back to the current token when refresh fails and it hasn't expired" do
      server.response_status = HTTP::Status::BAD_REQUEST
      server.response_body = %({"error": "invalid_grant"})
      expiry = 2.minutes.from_now.to_unix
      user = Generator.user(authority)
      user.access_token = "stored-access"
      user.refresh_token = "stored-refresh"
      user.expires = true
      user.expires_at = expiry
      user.save!

      token = user.resource_token(authority)
      token.token.should eq "stored-access"
      token.expires.should eq expiry
    end

    it "raises when refresh fails and the token has expired" do
      server.response_status = HTTP::Status::BAD_REQUEST
      server.response_body = %({"error": "invalid_grant"})
      user = Generator.user(authority)
      user.access_token = "stored-access"
      user.refresh_token = "stored-refresh"
      user.expires = true
      user.expires_at = 1.minute.ago.to_unix
      user.save!

      expect_raises(OAuth2::Error) { user.resource_token(authority) }
    end

    it "raises NoResourceToken without a refresh token" do
      user = Generator.user(authority)
      user.access_token = "stored-access"
      user.expires = true
      user.expires_at = 1.minute.ago.to_unix
      user.save!

      expect_raises(Error::NoResourceToken, "no refresh token available") { user.resource_token(authority) }
    end

    it "raises NoResourceToken without an oauth strategy" do
      bare = Generator.authority(domain: "http://no-strategy.#{RANDOM.hex(4)}.dev").save!
      user = Generator.user(bare)
      user.refresh_token = "stored-refresh"
      user.expires = true
      user.save!

      expect_raises(Error::NoResourceToken, "no oauth configuration found") { user.resource_token(bare) }
    end
  end
end
