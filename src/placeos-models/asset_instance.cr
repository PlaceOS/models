require "./base/model"
require "./user"

module PlaceOS::Model
  class AssetInstance < ModelBase
    include RethinkORM::Timestamps

    enum Tracking
      InStorage
      OnTheWay
      InRoom
      Returned
    end

    table :ass

    attribute tracking : Tracking = Tracking::InStorage
    attribute approval : Bool = false
    attribute requester : User?
    attribute duration_start : Time
    attribute duration_end : Time

    # Association
    ################################################################################################

    belongs_to Asset, foreign_key: "asset_id"
    belongs_to Zone, foreign_key: "zone_id"

    # Validation
    ###############################################################################################

    # Validate `duration_end`
    validate ->(this : AssetInstance) do
      this.validation_error(:duration_end, "duration end must be after duration start") if this.duration_end <= this.duration_start
    end

    # Queries
    ################################################################################################

    # Look up `AssetInstance`s belonging to `Asset`
    def self.of(asset_id)
      AssetInstance.by_asset_id(asset_id)
    end
  end
end