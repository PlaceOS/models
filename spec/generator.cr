require "faker"
require "random"

require "../src/placeos-models/*"
require "../src/placeos-models/**"

RANDOM = Random.new

module PlaceOS::Model
  # Defines generators for models
  module Generator
    def self.event_metadata(tenant_id, start : Time, ending : Time, system_id = "sys-1234")
      EventMetadata.new(
        system_id: system_id,
        event_start: start.to_unix,
        event_end: ending.to_unix,
        event_id: RANDOM.hex(4),
        ical_uid: RANDOM.hex(4),
        recurring_master_id: RANDOM.hex(4),
        resource_master_id: RANDOM.hex(4),
        host_email: Faker::Internet.email,
        resource_calendar: Faker::Internet.email,
        tenant_id: tenant_id
      )
    end

    def self.booking_attendee
      user_name = Faker::Hacker.noun
      user_email = Faker::Internet.email

      visitor_name = Faker::Hacker.noun
      visitor_email = Faker::Internet.email

      tenant_id = tenant.id

      booking = Booking.new(
        booking_type: "visitor",
        asset_id: visitor_email,
        booking_start: 1.hour.from_now.to_unix,
        booking_end: 2.hours.from_now.to_unix,
        user_email: PlaceOS::Model::Email.new(user_email),
        user_name: user_name,
        booked_by_email: PlaceOS::Model::Email.new(user_email),
        booked_by_name: user_name,
        tenant_id: tenant_id,
        booked_by_id: "user-1234",
        history: [] of Booking::History
      ).save!

      guest = Guest.new(
        email: visitor_email,
        name: visitor_name,
        tenant_id: tenant_id,
      ).save!

      Attendee.new(
        tenant_id: tenant_id,
        visit_expected: true,
        booking_id: booking.id,
        guest_id: guest.id,
        checked_in: false,
      ).save!

      booking.id
    end

    def self.booking(tenant_id, asset_id : String, start : Time, ending : Time, booking_type = "booking", parent_id = nil, event_id = nil)
      user_name = Faker::Hacker.noun
      user_email = Faker::Internet.email
      Booking.new(
        booking_type: booking_type,
        asset_id: asset_id,
        booking_start: start.to_unix,
        booking_end: ending.to_unix,
        user_email: PlaceOS::Model::Email.new(user_email),
        user_name: user_name,
        booked_by_email: PlaceOS::Model::Email.new(user_email),
        booked_by_name: user_name,
        tenant_id: tenant_id,
        parent_id: parent_id,
        event_id: event_id,
        booked_by_id: "user-1234",
        history: [] of Booking::History
      )
    end

    def self.playlist(
      name : String = Faker::Hacker.noun,
      description : String = "",
      authority : Authority? = nil,
    )
      unless authority
        # look up an existing authority
        existing = Authority.find_by_domain("localhost")
        authority = existing || self.authority.save!
      end

      play = Playlist.new(
        name: name,
        description: description,
        authority_id: authority.id
      )
      play
    end

    def self.revision(playlist : Playlist = playlist.save!, user : User = user.save!)
      rev = Playlist::Revision.new
      rev.playlist_id = playlist.id
      rev.user = user
      rev
    end

    def self.shortener(
      uri : String = "https://google.com.au/maps",
      user : User = user.save!,
      authority : Authority? = nil,
    )
      unless authority
        # look up an existing authority
        existing = Authority.find_by_domain("localhost")
        authority = existing || self.authority.save!
      end

      short = Shortener.new(
        name: uri,
        uri: uri,
        authority_id: authority.id
      )
      short.user = user
      short
    end

    def self.item(
      name : String = Faker::Hacker.noun,
      media_uri : String = "https://placeos.com/",
      media_id : String? = nil,
      authority : Authority? = nil,
    )
      unless authority
        # look up an existing authority
        existing = Authority.find_by_domain("localhost")
        authority = existing || self.authority.save!
      end

      item = Playlist::Item.new
      item.authority_id = authority.id
      item.name = name
      item.media_uri = media_uri
      if media_id
        item.media_id = media_id
        item.media_type = Playlist::Item::MediaType::Image
      else
        item.media_type = Playlist::Item::MediaType::Webpage
      end
      item
    end

    def self.booking(tenant_id, asset_ids : Array(String), start : Time, ending : Time, booking_type = "booking", parent_id = nil, event_id = nil)
      user_name = Faker::Hacker.noun
      user_email = Faker::Internet.email
      Booking.new(
        booking_type: booking_type,
        asset_ids: asset_ids,
        booking_start: start.to_unix,
        booking_end: ending.to_unix,
        user_email: PlaceOS::Model::Email.new(user_email),
        user_name: user_name,
        booked_by_email: PlaceOS::Model::Email.new(user_email),
        booked_by_name: user_name,
        tenant_id: tenant_id,
        parent_id: parent_id,
        event_id: event_id,
        booked_by_id: "user-1234",
        history: [] of Booking::History
      )
    end

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

    def self.json_schema
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
        mod.control_system = !control_system ? Generator.control_system.save! : control_system
      end
      mod
    end

    def self.edge(user : User? = nil)
      user = self.user.save! if user.nil?
      Edge.for_user(user, name: "#{Faker::Address.city}_#{RANDOM.base64(5)}")
    end

    def self.encryption_level
      Encryption::Level.parse(Encryption::Level.names.sample(1).first)
    end

    def self.metadata(
      name : String = Faker::Hacker.noun + RANDOM.base64(10),
      parent : String | User | Zone | ControlSystem? = nil,
      modifier : User? = nil,
    )
      Metadata.new(name: name, details: JSON::Any.new({} of String => JSON::Any)).tap do |meta|
        case parent
        in ControlSystem then meta.control_system = parent
        in String        then meta.parent_id = parent
        in User          then meta.user = parent
        in Zone          then meta.zone = parent
        in Nil
          # Generate a single parent for the metadata model
          {
            -> { meta.control_system = self.control_system.save! },
            -> { meta.zone = self.zone.save! },
            -> { meta.user = self.user.save! },
          }.sample.call
        end

        modifier = user.save! if modifier.nil?
        meta.modified_by = modifier
      end
    end

    def self.settings(
      settings_string = "{}",
      encryption_level = self.encryption_level,
      driver : Driver? = nil,
      mod : Module? = nil,
      control_system : ControlSystem? = nil,
      zone : Zone? = nil,
      parent : Union(Zone, ControlSystem, Driver, Module)? = nil,
      modifier : User? = nil,
    ) : Settings
      Settings.new(
        settings_string: settings_string,
        encryption_level: encryption_level,
      ).tap do |settings|
        settings.control_system = control_system if control_system
        settings.driver = driver if driver
        settings.mod = mod if mod
        settings.zone = zone if zone
        settings.parent = parent if parent

        unless {parent, control_system, driver, mod, zone}.one?
          # Generate a single parent for the settings model
          {
            -> { settings.control_system = self.control_system.save! },
            -> { settings.driver = self.driver.save! },
            -> { settings.mod = self.module.save! },
            -> { settings.zone = self.zone.save! },
          }.sample.call
        end

        settings.parse_parent_type
        modifier = user.save! if modifier.nil?
        settings.modified_by = modifier
      end
    end

    def self.zone
      Zone.new(
        name: RANDOM.base64(10),
      )
    end

    def self.asset_category
      AssetCategory.new(
        name: Faker::Hacker.noun,
      )
    end

    def self.asset_type(category = Generator.asset_category.save!)
      AssetType.new(
        name: Faker::Hacker.noun,
        brand: Faker::Hacker.noun,
        category_id: category.id,
      )
    end

    class_getter asset_zone : Zone { self.zone.save! }

    def self.asset(asset_type = Generator.asset_type.save!, purchase_order = Generator.asset_purchase_order.save!)
      Asset.new(
        asset_type_id: asset_type.id,
        purchase_order_id: purchase_order.id,
        zone_id: asset_zone.id,
      )
    end

    def self.asset_purchase_order
      AssetPurchaseOrder.new(
        purchase_order_number: Faker::Hacker.noun,
      )
    end

    def self.authority(domain : String = "http://localhost", email_domains : Array(String) = [] of String)
      Authority.new(
        name: Faker::Hacker.noun,
        domain: domain,
        email_domains: email_domains
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
        email: Email.new(Random.rand(9999).to_s + Faker::Internet.email),
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
        email: user.email.to_s,
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
      permission : UserJWT::Permissions? = nil,
    )
      meta = UserJWT::Metadata.new(
        name: name || Faker::Hacker.noun,
        email: email || Faker::Internet.email,
        permissions: permission || self.permissions
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

    MOCK_TENANT_PARAMS = {
      name:           "Toby",
      platform:       "office365",
      domain:         "toby.staff-api.dev",
      credentials:    %({"tenant":"bb89674a-238b-4b7d-91ec-6bebad83553a","client_id":"6316bc86-b615-49e0-ad24-985b39898cb7","client_secret": "k8S1-0c5PhIh:[XcrmuAIsLo?YA[=-GS"}),
      delegated:      false,
      outlook_config: Tenant::OutlookConfig.from_json(%({"app_id": "0114c179-de01-4707-b558-b4b535551b91"})),
    }

    def self.tenant(params = MOCK_TENANT_PARAMS)
      Tenant.create(**params)
    end

    def self.tenant(
      *,
      name = "Toby",
      platform = "office365",
      domain = "toby.staff-api.dev",
      credentials = %({"tenant":"bb89674a-238b-4b7d-91ec-6bebad83553a","client_id":"6316bc86-b615-49e0-ad24-985b39898cb7","client_secret": "k8S1-0c5PhIh:[XcrmuAIsLo?YA[=-GS"}),
      delegated = false,
      outlook_config = Tenant::OutlookConfig.from_json(%({"app_id": "0114c179-de01-4707-b558-b4b535551b91"})),
    )
      Tenant.create(
        name: name,
        platform: platform,
        domain: domain,
        credentials: credentials,
        delegated: delegated,
        outlook_config: outlook_config
      )
    end

    def self.storage(type = Storage::Type::S3, bucket : String? = nil, authority_id : String? = nil)
      Storage.new(storage_type: type, bucket_name: bucket || Faker::Hacker.noun,
        access_key: Faker::Hacker.noun, access_secret: Faker::Hacker.noun,
        authority_id: authority_id)
    end

    def self.upload(uploader : User? = nil, storage_id : String? = nil,
                    file_name : String? = nil, file_size : Int64 = 5120,
                    object_key : String? = nil, file_md5 : String? = nil,
                    permissions = Upload::Permissions::Admin)
      uploader = uploader || self.user(admin: true).save!
      Upload.new(uploaded_by: uploader.id, uploaded_email: uploader.email,
        storage_id: storage_id || self.storage.save!.id,
        file_name: file_name || Faker::Hacker.noun,
        file_size: file_size, file_md5: file_md5 || Faker::Hacker.noun,
        object_key: object_key || Faker::Hacker.noun,
        permissions: permissions)
    end

    def self.chat(user : User? = nil, system : ControlSystem? = nil, summary : String? = nil)
      u = user || self.user.save!
      s = system || self.control_system.save!

      Chat.new(user_id: u.id.not_nil!, system_id: s.id.not_nil!, summary: summary || Faker::Lorem.paragraph)
    end

    def self.chat_message(chat : Chat? = nil, role = ChatMessage::Role::User, content : String? = nil, func_name : String? = nil,
                          func_args : JSON::Any? = nil, tool_call_id : String? = nil)
      cid = chat || self.chat.save!
      msg = content || Faker::Lorem.paragraph
      func = func_name || Faker::Internet.slug
      call_id = tool_call_id || "Call_#{Faker::Internet.slug}"

      ChatMessage.new(chat_id: cid.id, role: role, content: msg, function_name: func, tool_call_id: call_id)
    end

    def self.survey(
      title : String = Faker::Hacker.abbreviation,
      description : String = Faker::Hacker.say_something_smart,
      trigger : Survey::TriggerType = Survey::TriggerType::NONE,
      zone_id : String = "",
      building_id = "",
      pages : Array(Survey::Page) = [self.page],
    )
      Survey.new(
        title: title,
        description: description,
        trigger: trigger,
        zone_id: zone_id,
        building_id: building_id,
        pages: pages,
      )
    end

    def self.page(
      title : String = Faker::Hacker.adjective,
      description : String = Faker::Hacker.say_something_smart,
      question_order : Array(Int64) = [] of Int64,
    )
      Survey::Page.new(
        title: title,
        description: description,
        question_order: question_order,
      )
    end

    def self.question(
      title : String = Faker::Hacker.noun,
      description : String = Faker::Hacker.say_something_smart,
      type : String = "text",
      options : JSON::Any = JSON::Any.new({} of String => JSON::Any),
      required : Bool = false,
      choices : JSON::Any = JSON::Any.new({} of String => JSON::Any),
      max_rating : Int32? = nil,
      tags : Array(String) = [] of String,
      deleted_at : Int64? = nil,
    )
      Survey::Question.new(
        title: title,
        description: description,
        type: type,
        options: options,
        required: required,
        choices: choices,
        max_rating: max_rating,
        tags: tags,
        deleted_at: deleted_at,
      )
    end

    def self.invitation(
      survey_id : Int64? = nil,
      email : String = Faker::Internet.email,
      sent : Bool? = nil,
    )
      id = survey_id || self.survey.save!.id
      Survey::Invitation.new(
        survey_id: id,
        email: email,
        sent: sent,
      )
    end

    def self.alert_dashboard(
      name : String = Faker::Lorem.word,
      description : String = Faker::Lorem.sentence,
      enabled : Bool = true,
      authority_id : String? = nil,
    )
      unless authority_id
        # look up an existing authority
        existing = Authority.find_by_domain("localhost")
        authority = existing || self.authority.save!
        authority_id = authority.id
      end

      AlertDashboard.new(
        name: name,
        description: description,
        enabled: enabled,
        authority_id: authority_id
      )
    end

    def self.alert(
      name : String = Faker::Lorem.word,
      description : String = Faker::Lorem.sentence,
      enabled : Bool = true,
      severity : Alert::Severity = Alert::Severity::MEDIUM,
      alert_type : Alert::AlertType = Alert::AlertType::THRESHOLD,
      debounce_period : Int32 = 60000,
      alert_dashboard_id : String? = nil,
    )
      unless alert_dashboard_id
        # generate a dashboard if none provided
        dashboard = self.alert_dashboard.save!
        alert_dashboard_id = dashboard.id
      end

      Alert.new(
        name: name,
        description: description,
        enabled: enabled,
        severity: severity,
        alert_type: alert_type,
        debounce_period: debounce_period,
        alert_dashboard_id: alert_dashboard_id
      )
    end

    def self.history(
      type : String = "zone",
      resource_id : String = "zone-#{RANDOM.hex(4)}",
      changed_fields : Array(String) = ["name", "description"],
    )
      History.new(
        type: type,
        resource_id: resource_id,
        changed_fields: changed_fields
      )
    end
  end
end
