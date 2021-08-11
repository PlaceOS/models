require "faker"
require "random"

require "../src/placeos-models/*"
require "../src/placeos-models/**"

RANDOM = Random.new

module PlaceOS::Model
  # Defines generators for models
  module Generator
    def self.driver(role : Driver::Role? = nil, module_name : String? = nil, repo : Repository? = nil)
      role = self.role unless role
      repo = self.repository(type: Repository::Type::Driver).save! unless repo
      module_name = Faker::Hacker.noun unless module_name

      driver = Driver.new(
        name: RANDOM.base64(10),
        commit: RANDOM.hex(7),
        module_name: module_name,
      )

      driver.file_name = "drivers/#{repository.name}/#{driver.name}.cr"
      driver.role = role
      driver.repository = repo.not_nil!
      driver
    end

    def self.schema
      schema = JsonSchema.new
      schema.name = "test"
      schema.schema = JSON.parse %({
        "title": "Person",
        "type": "object",
        "properties": {
          "firstName": {
            "type": "string",
            "description": "The person's first name."
          },
          "lastName": {
            "type": "string",
            "description": "The person's last name."
          },
          "age": {
            "description": "Age in years which must be equal to or greater than zero.",
            "type": "integer",
            "minimum": 0
          }
        }
      })
      schema
    end

    def self.role
      role_value = Driver::Role.names.sample(1).first
      Driver::Role.parse(role_value)
    end

    def self.repository_type
      type = Repository::Type.names.sample(1).first
      Repository::Type.parse(type)
    end

    def self.repository(type : Repository::Type? = nil)
      type = self.repository_type unless type
      Repository.new(
        name: Faker::Hacker.noun,
        repo_type: type,
        folder_name: UUID.random.to_s,
        description: Faker::Hacker.noun,
        uri: Faker::Internet.url,
        commit_hash: "HEAD",
      )
    end

    def self.trigger(system : ControlSystem? = nil)
      trigger = Trigger.new(
        name: Faker::Hacker.noun,
      )
      trigger.control_system = system if system
      trigger
    end

    def self.trigger_instance(trigger = nil, zone = nil, control_system = nil)
      trigger = self.trigger.save! unless trigger
      instance = TriggerInstance.new(important: false)
      instance.trigger = trigger

      instance.zone = zone if zone

      instance.control_system = control_system ? control_system : self.control_system.save!

      instance
    end

    def self.control_system
      ControlSystem.new(
        name: RANDOM.base64(10),
      )
    end

    def self.module(driver = nil, control_system = nil)
      mod_name = Faker::Hacker.noun

      driver = Generator.driver(module_name: mod_name) if driver.nil?
      driver.save! unless driver.persisted?

      mod = case driver.role
            in .logic?
              Module.new(custom_name: mod_name, uri: Faker::Internet.url)
            in .device?
              Module.new(
                custom_name: mod_name,
                uri: Faker::Internet.url,
                ip: Faker::Internet.ip_v4_address,
                port: rand((1..6555)),
              )
            in .ssh?
              Module.new(
                custom_name: mod_name,
                uri: Faker::Internet.url,
                ip: Faker::Internet.ip_v4_address,
                port: rand((1..65_535)),
              )
            in .service?, .websocket?
              Module.new(custom_name: mod_name, uri: Faker::Internet.url)
            end

      # Set driver
      mod.driver = driver

      if driver.role.logic?
        begin
          # Set cs
          mod.control_system = !control_system ? Generator.control_system.save! : control_system
        rescue e : RethinkORM::Error::DocumentInvalid
          pp! e.model.not_nil!.errors
          raise e
        end
      end
      mod
    end

    def self.edge
      Edge.new(name: "#{Faker::Address.city}_#{RANDOM.base64(5)}")
    end

    def self.encryption_level
      Encryption::Level.parse(Encryption::Level.names.sample(1).first)
    end

    def self.metadata(name : String = Faker::Hacker.noun + RANDOM.base64(10), parent : String | Zone | ControlSystem? = nil)
      meta = Metadata.new(name: name, details: JSON::Any.new({} of String => JSON::Any))

      case parent
      in ControlSystem
        meta.control_system = control_system
      in String
        meta.parent_id = parent
      in Zone
        meta.zone = zone
      in Nil
        # Generate a single parent for the metadata model
        {
          ->{ meta.control_system = self.control_system.save! },
          ->{ meta.zone = self.zone.save! },
        }.sample.call
      end

      meta
    end

    def self.settings(
      settings_string = "{}",
      encryption_level = self.encryption_level,
      driver : Driver? = nil,
      mod : Module? = nil,
      control_system : ControlSystem? = nil,
      zone : Zone? = nil,
      parent : Union(Zone, ControlSystem, Driver, Module)? = nil
    ) : Settings
      settings = Settings.new(
        settings_string: settings_string,
        encryption_level: encryption_level,
      )

      settings.control_system = control_system if control_system
      settings.driver = driver if driver
      settings.mod = mod if mod
      settings.zone = zone if zone
      settings.parent = parent if parent

      unless {parent, control_system, driver, mod, zone}.one?
        # Generate a single parent for the settings model
        {
          ->{ settings.control_system = self.control_system.save! },
          ->{ settings.driver = self.driver.save! },
          ->{ settings.mod = self.module.save! },
          ->{ settings.zone = self.zone.save! },
        }.sample.call
      end

      settings
    end

    def self.zone
      Zone.new(
        name: RANDOM.base64(10),
      )
    end

    def self.authority(domain : String = "http://localhost")
      Authority.new(
        name: Faker::Hacker.noun,
        domain: domain,
      )
    end

    def self.user(authority : Authority? = nil, support : Bool = false, admin : Bool = false)
      unless authority
        # look up an existing authority
        existing = Authority.find_by_domain("localhost")
        authority = existing || self.authority.save!
      end

      User.new(
        name: Faker::Name.name,
        email: Random.rand(9999).to_s + Faker::Internet.email,
        authority_id: authority.id,
        sys_admin: admin,
        support: support,
      )
    end

    def self.authenticated_user(authority = nil)
      user = self.user(authority)
      user.support = true
      user.sys_admin = true
      user
    end

    def self.api_key(authority : Authority? = nil, support : Bool = false, admin : Bool = false)
      user = self.user(authority, support, admin)
      user.save!
      key = ApiKey.new
      key.name = Faker::Name.name
      key.user = user
      key
    end

    def self.adfs_strat(authority : Authority? = nil)
      unless authority
        # look up an existing authority
        existing = Authority.find_by_domain("localhost")
        authority = existing || self.authority.save!
      end

      SamlAuthentication.new(
        name: Faker::Name.name,
        authority_id: authority.id,
        assertion_consumer_service_url: Faker::Internet.url,
        idp_sso_target_url: Faker::Internet.url,
      )
    end

    def self.oauth_strat(authority : Authority? = nil)
      unless authority
        # look up an existing authority
        existing = Authority.find_by_domain("localhost")
        authority = existing || self.authority.save!
      end

      OAuthAuthentication.new(
        name: Faker::Name.name,
        authority_id: authority.id,
        client_id: RANDOM.hex(32),
        client_secret: RANDOM.hex(64),
        site: Faker::Internet.url,
        scope: "public:read",
      )
    end

    def self.ldap_strat(authority : Authority? = nil)
      unless authority
        # look up an existing authority
        existing = Authority.find_by_domain("localhost")
        authority = existing || self.authority.save!
      end

      LdapAuthentication.new(
        name: Faker::Name.name,
        authority_id: authority.id,
        host: Faker::Internet.domain_name,
        port: rand(1..65535),
        base: "/",
      )
    end

    def self.broker
      Broker.new(
        name: Faker::Name.name,
        host: Faker::Internet.domain_name,
      )
    end

    def self.bool
      [true, false].sample(1).first
    end

    def self.jwt(user : User? = nil, scope : Array(UserJWT::Scope) = [UserJWT::Scope.new("public")])
      user = self.user.save! if user.nil?

      permissions = case ({user.support, user.sys_admin})
                    when {true, true}  then UserJWT::Permissions::AdminSupport
                    when {true, false} then UserJWT::Permissions::Support
                    when {false, true} then UserJWT::Permissions::Admin
                    else                    UserJWT::Permissions::User
                    end

      meta = UserJWT::Metadata.new(
        name: user.name,
        email: user.email,
        permissions: permissions
      )

      UserJWT.new(
        iss: "POS",
        iat: Time.utc,
        exp: 2.weeks.from_now,
        domain: Faker::Internet.email,
        id: user.id.as(String),
        scope: scope,
        user: meta,
      )
    end

    def self.permissions
      UserJWT::Permissions.parse(UserJWT::Permissions.names.sample(1).first)
    end

    def self.user_jwt(
      id : String? = nil,
      domain : String? = nil,
      name : String? = nil,
      email : String? = nil,
      permission : UserJWT::Permissions? = nil
    )
      meta = UserJWT::Metadata.new(
        name: name || Faker::Hacker.noun,
        email: email || Faker::Internet.email,
        permissions: permissions || self.permissions
      )

      UserJWT.new(
        iss: "POS",
        iat: Time.utc,
        exp: 2.weeks.from_now,
        domain: Faker::Internet.email,
        id: id || RANDOM.base64(10),
        user: meta,
      )
    end
  end
end
