require "json"
require "place_calendar"

module PlaceOS::Model
  class Tenant < ModelWithAutoKey
    VALID_PLATFORMS = ["office365", "google"]

    struct OutlookConfig
      include JSON::Serializable

      property app_id : String = ""
      property base_path : String?
      property app_domain : String?
      property app_resource : String?
      property source_location : String?
      property version : String?

      def clean
        self.app_id = self.app_id.strip.downcase
        self.base_path = self.base_path.try &.blank? ? nil : self.base_path.try &.strip.downcase
        self.app_domain = self.app_domain.try &.blank? ? nil : self.app_domain.try &.strip.downcase
        self.app_resource = self.app_resource.try &.blank? ? nil : self.app_resource.try &.strip.downcase
        self.source_location = self.source_location.try &.blank? ? nil : self.source_location.try &.strip.downcase
        self.version = self.version.try &.blank? ? nil : self.version.try &.strip
        self
      end

      def params
        {
          app_id:          @app_id,
          base_path:       @base_path,
          app_domain:      @app_domain,
          app_resource:    @app_resource,
          source_location: @source_location,
          version:         @version,
        }
      end

      def self.from_json(val)
        if val == "null"
          nil
        else
          OutlookConfig.new(JSON::PullParser.new(val))
        end
      end
    end

    struct Office365Config
      include JSON::Serializable

      property tenant : String
      property client_id : String
      property client_secret : String
      property conference_type : String? # = PlaceCalendar::Office365::DEFAULT_CONFERENCE
      property scopes : String = PlaceCalendar::Office365::DEFAULT_SCOPE

      def params
        {
          tenant:          @tenant,
          client_id:       @client_id,
          client_secret:   @client_secret,
          conference_type: @conference_type,
          scopes:          @scopes,
        }
      end
    end

    struct GoogleConfig
      include JSON::Serializable

      property issuer : String
      property signing_key : String
      property scopes : String | Array(String)
      property domain : String
      property sub : String = ""
      property user_agent : String = "PlaceOS"
      property conference_type : String? # = PlaceCalendar::Google::DEFAULT_CONFERENCE

      def params
        {
          issuer:          @issuer,
          signing_key:     @signing_key,
          scopes:          @scopes,
          domain:          @domain,
          sub:             @sub,
          user_agent:      @user_agent,
          conference_type: @conference_type,
        }
      end
    end

    struct GoogleDelegatedConfig
      include JSON::Serializable

      property domain : String
      property user_agent : String = "PlaceOS"
      property conference_type : String? # = PlaceCalendar::Google::DEFAULT_CONFERENCE

      def params
        {
          domain:          @domain,
          user_agent:      @user_agent,
          conference_type: @conference_type,
        }
      end
    end

    struct Office365DelegatedConfig
      include JSON::Serializable

      property conference_type : String? # = PlaceCalendar::Office365::DEFAULT_CONFERENCE

      def params
        {
          conference_type: @conference_type,
        }
      end
    end
  end
end
