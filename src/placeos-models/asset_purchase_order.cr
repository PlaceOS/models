require "./base/model"
require "./asset"

module PlaceOS::Model
  class AssetPurchaseOrder < ModelWithAutoKey
    include PlaceOS::Model::Timestamps

    table :asset_purchase_order

    attribute purchase_order_number : String, es_type: "keyword"
    attribute invoice_number : String?
    attribute supplier_details : JSON::Any?
    attribute purchase_date : Time?

    attribute unit_price : Int64?
    attribute expected_service_start_date : Time?
    attribute expected_service_end_date : Time?

    has_many(
      child_class: Asset,
      foreign_key: "purchase_order_id",
      collection_name: :assets
    )
  end
end
