require "./base/model"
require "./asset_type"
require "./asset_purchase_order"

module PlaceOS::Model
  class Asset < ModelBase
    include PlaceOS::Model::Timestamps

    table :asset

    attribute model_number : String
    attribute serial_number : String
    attribute identifier : String?
    attribute other_data : JSON::Any?
    attribute images : Array(String)?
    attribute purchase_price_in_cents : Int64?
    attribute salvage_value_in_cents : Int64?
    attribute expected_service_start_date : Time?
    attribute expected_service_end_date : Time?

    belongs_to AssetType, foreign_key: "asset_type_id", association_name: "asset_type"
    belongs_to AssetPurchaseOrder, foreign_key: "purchase_order_id", association_name: "purchase_order"
  end
end
