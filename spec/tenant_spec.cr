require "./helper"

module PlaceOS::Model
  def self.get_tenant
    Generator.tenant
    Tenant.find_by(domain: "toby.staff-api.dev")
  end

  Spec.before_each do
    Tenant.clear
  end
  describe Tenant do
    test_round_trip(Tenant)

    it "valid input raises no errors" do
      Generator.tenant({
        name:        "Jon",
        platform:    "google",
        domain:      "google.staff-api.dev",
        credentials: %({"issuer":"1122121212","scopes":["http://example.com"],"signing_key":"-----BEGIN PRIVATE KEY-----SOMEKEY DATA-----END PRIVATE KEY-----","domain":"example.com.au","sub":"jon@example.com.au"}),
      })
    end

    it "prevents two tenants with the same domain" do
      Generator.tenant({
        name:        "Bob",
        platform:    "google",
        domain:      "club-bob.staff-api.dev",
        credentials: %({
              "issuer":      "1122121212",
              "scopes":      ["http://example.com"],
              "signing_key": "-----BEGIN PRIVATE KEY-----SOMEKEY DATA-----END PRIVATE KEY-----",
              "domain":      "example.com.au",
              "sub":         "bob@example.com.au"
            }),
      })

      expect_raises(PgORM::Error::RecordInvalid, "`domain` should be unique") do
        Generator.tenant({
          name:        "Ian",
          platform:    "google",
          domain:      "club-bob.staff-api.dev",
          credentials: %({
              "issuer":      "1122121212",
              "scopes":      ["http://example.com"],
              "signing_key": "-----BEGIN PRIVATE KEY-----SOMEKEY DATA-----END PRIVATE KEY-----",
              "domain":      "example.com.au",
              "sub":         "bob@example.com.au"
            }),
        })
      end
    end

    it "allows two tenants with the same domain if email_domain is provided" do
      Generator.tenant({
        name:        "Bob",
        platform:    "google",
        domain:      "club-bob.staff-api.dev",
        credentials: %({
              "issuer":      "1122121212",
              "scopes":      ["http://example.com"],
              "signing_key": "-----BEGIN PRIVATE KEY-----SOMEKEY DATA-----END PRIVATE KEY-----",
              "domain":      "example.com.au",
              "sub":         "bob@example.com.au"
            }),
      })

      Generator.tenant({
        name:         "Bob2",
        platform:     "google",
        domain:       "club-bob.staff-api.dev",
        email_domain: "other.client.domain",
        credentials:  %({
          "issuer":      "1122121212",
          "scopes":      ["http://example.com"],
          "signing_key": "-----BEGIN PRIVATE KEY-----SOMEKEY DATA-----END PRIVATE KEY-----",
          "domain":      "example.com.au",
          "sub":         "bob@example.com.au"
        }),
      })

      Generator.tenant({
        name:         "Bob3",
        platform:     "google",
        domain:       "club-bob.staff-api.dev",
        email_domain: "some.client.domain",
        credentials:  %({
          "issuer":      "1122121212",
          "scopes":      ["http://example.com"],
          "signing_key": "-----BEGIN PRIVATE KEY-----SOMEKEY DATA-----END PRIVATE KEY-----",
          "domain":      "example.com.au",
          "sub":         "bob@example.com.au"
        }),
      })

      expect_raises(PgORM::Error::RecordInvalid, "`domain` should be unique") do
        Generator.tenant({
          name:         "Bob4",
          platform:     "google",
          domain:       "club-bob.staff-api.dev",
          email_domain: "some.client.domain",
          credentials:  %({
            "issuer":      "1122121212",
            "scopes":      ["http://example.com"],
            "signing_key": "-----BEGIN PRIVATE KEY-----SOMEKEY DATA-----END PRIVATE KEY-----",
            "domain":      "example.com.au",
            "sub":         "bob@example.com.au"
          }),
        })
      end
    end

    it "should accept booking limits" do
      a = Generator.tenant({
        name:           "Jon2",
        platform:       "google",
        domain:         "google.staff-api.dev",
        credentials:    %({"issuer":"1122121212","scopes":["http://example.com"],"signing_key":"-----BEGIN PRIVATE KEY-----SOMEKEY DATA-----END PRIVATE KEY-----","domain":"example.com.au","sub":"jon@example.com.au"}),
        booking_limits: JSON.parse({"desk": 2}.to_json),
      })
      a.booking_limits.should eq({"desk" => 2})
    end

    it "should validate booking limits" do
      expect_raises(PgORM::Error::RecordInvalid, "`booking_limits` Expected Int but was String") do
        Generator.tenant({
          name:           "Jon2",
          platform:       "google",
          domain:         "google.staff-api.dev",
          credentials:    %({"issuer":"1122121212","scopes":["http://example.com"],"signing_key":"-----BEGIN PRIVATE KEY-----SOMEKEY DATA-----END PRIVATE KEY-----","domain":"example.com.au","sub":"jon@example.com.au"}),
          booking_limits: JSON.parse({"desk": "2"}.to_json),
        })
      end
    end

    it "check encryption" do
      t = Generator.tenant({
        name:        "Jon2",
        platform:    "google",
        domain:      "encrypt.google.staff-api.dev",
        credentials: %({"issuer":"1122121212","scopes":["http://example.com"],"signing_key":"-----BEGIN PRIVATE KEY-----SOMEKEY DATA-----END PRIVATE KEY-----","domain":"example.com.au","sub":"jon@example.com.au"}),
      })
      t.is_encrypted?.should be_true
      t.using_service_account?.should be_false
    end

    it "should create a tenant with a service account" do
      t = Generator.tenant({
        name:            "Jon2",
        platform:        "google",
        domain:          "encrypt.google.staff-api.dev",
        service_account: "steve@org.com",
        credentials:     %({"issuer":"1122121212","scopes":["http://example.com"],"signing_key":"-----BEGIN PRIVATE KEY-----SOMEKEY DATA-----END PRIVATE KEY-----","domain":"example.com.au","sub":"jon@example.com.au"}),
      })
      t.is_encrypted?.should be_true
      t.using_service_account?.should be_true
      t.which_account("otheruser@email.com").should eq("steve@org.com")
    end
  end

  describe "#decrypt_for" do
    tenant = Generator.tenant

    UserJWT::Permissions.each do |permission|
      it "does not decrypt for #{permission.to_json}" do
        token = Generator.user_jwt(permission: permission)
        PlaceOS::Encryption.is_encrypted?(tenant.decrypt_for(token)).should be_true
      end
    end
  end

  it "takes JSON credentials and returns a PlaceCalendar::Client" do
    tenant = get_tenant
    tenant.place_calendar_client.class.should eq(PlaceCalendar::Client)
  end

  it "should validate credentials based on platform" do
    tenant = get_tenant
    expect_raises(PgORM::Error::RecordInvalid) do
      tenant.update(platform: "google")
    end
  end
end
