require "json"
require "./base/model"
require "./trigger/conditions"

module PlaceOS::Model
  class Alert < ModelBase
    include PlaceOS::Model::Timestamps

    table :alert

    enum Severity
      LOW
      MEDIUM
      HIGH
      CRITICAL
    end

    enum AlertType
      THRESHOLD
      STATUS
      CUSTOM
    end

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""
    attribute enabled : Bool = true

    # Reuse the same conditions structure as Trigger
    attribute conditions : PlaceOS::Model::Trigger::Conditions = -> { PlaceOS::Model::Trigger::Conditions.new }, es_ignore: true

    attribute severity : Severity = Severity::MEDIUM, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Alert::Severity)
    attribute alert_type : AlertType = AlertType::THRESHOLD, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Alert::AlertType)

    # In milliseconds - delay before showing notification to prevent flapping
    attribute debounce_period : Int32 = 15000 # 15 seconds default

    # Association
    ###############################################################################################

    belongs_to AlertDashboard, foreign_key: "alert_dashboard_id"

    # Validation
    ###############################################################################################

    validates :name, presence: true
    validates :alert_dashboard_id, presence: true

    # Validation of conditions
    validate ->(this : Alert) do
      if !this.conditions.valid?
        this.conditions.errors.each do |e|
          this.validation_error(:condition, e.to_s)
        end
      end
    end

    # Helpers
    ###############################################################################################

    def critical?
      severity == Severity::CRITICAL
    end

    def high_priority?
      severity.in?([Severity::HIGH, Severity::CRITICAL])
    end
  end
end
