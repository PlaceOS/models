require "./base/model"
require "./asset_type"
require "./asset_purchase_order"

module PlaceOS::Model
  class Asset < ModelBase
    include PlaceOS::Model::Timestamps

    table :asset

    attribute identifier : String?
    attribute serial_number : String?
    attribute other_data : JSON::Any?

    belongs_to AssetType, foreign_key: "asset_type_id", association_name: "asset_type"
    belongs_to AssetPurchaseOrder, foreign_key: "purchase_order_id", association_name: "purchase_order"
  end
end
