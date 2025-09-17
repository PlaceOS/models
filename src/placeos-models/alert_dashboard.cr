require "json"
require "./base/model"

module PlaceOS::Model
  class AlertDashboard < ModelBase
    include PlaceOS::Model::Timestamps

    table :alert_dashboard

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""
    attribute enabled : Bool = true

    # Association
    ###############################################################################################

    belongs_to Authority, foreign_key: "authority_id"

    has_many(
      child_class: Alert,
      dependent: :destroy,
      foreign_key: "alert_dashboard_id",
      collection_name: :alerts
    )

    # Validation
    ###############################################################################################

    validates :name, presence: true
    validates :authority_id, presence: true

    # Helpers
    ###############################################################################################

    def active_alerts
      alerts.where(enabled: true)
    end
  end
end
