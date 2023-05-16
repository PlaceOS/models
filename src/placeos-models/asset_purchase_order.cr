require "./base/model"
require "./asset"

module PlaceOS::Model
  class AssetPurchaseOrder < ModelBase
    include PlaceOS::Model::Timestamps

    table :asset_purchase_order

    attribute purchase_order_number : String
    attribute invoice_number : String?
    attribute purchase_date : Time
    attribute depreciation_start_date : Time?
    attribute depreciation_end_date : Time?

    has_many(
      child_class: Asset,
      foreign_key: "purchase_order_id",
      collection_name: :assets
    )
  end
end
