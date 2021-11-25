require "./base/model"

module PlaceOS::Model
  class AssetInstance < ModelBase
    include RethinkORM::Timestamps

    table :ass

    attribute tracking : String = "In Storage"
    attribute approval : Bool = false
    attribute requester_id : String?
    attribute requester_email : String?
    attribute duration_start : Int64
    attribute duration_end : Int64

    # Association
    ################################################################################################

    belongs_to Asset, foreign_key: "asset_id"
    belongs_to Zone, foreign_key: "zone_id"
  end
end
