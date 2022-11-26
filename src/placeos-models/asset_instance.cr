require "./base/model"
require "./user"

module PlaceOS::Model
  class AssetInstance < ModelBase
    include PgORM::Timestamps

    enum Tracking
      InStorage
      OnTheWay
      InRoom
      Returned
    end

    table :ass

    attribute name : String, es_subfield: "keyword"
    attribute tracking : Tracking = Tracking::InStorage, converter: PlaceOS::Model::EnumConverter(PlaceOS::Model::AssetInstance::Tracking)
    attribute approval : Bool = false

    attribute asset_id : String
    attribute requester_id : String?
    attribute zone_id : String?

    attribute usage_start : Time
    attribute usage_end : Time

    # Association
    ################################################################################################

    belongs_to Asset, foreign_key: "asset_id"
    belongs_to Zone, foreign_key: "zone_id"
    belongs_to User, foreign_key: "requester_id"

    # Validation
    ###############################################################################################

    # Validate `usage_end`
    validate ->(this : AssetInstance) do
      this.validation_error(:usage_end, "usage end must be after usage start") if this.usage_end <= this.usage_start
    end

    # Queries
    ################################################################################################

    # Look up `AssetInstance`s belonging to `Asset`
    def self.of(asset_id)
      AssetInstance.by_asset_id(asset_id)
    end
  end
end
