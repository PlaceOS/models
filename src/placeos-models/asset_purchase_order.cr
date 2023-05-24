require "./base/model"
require "./asset"

module PlaceOS::Model
  class AssetPurchaseOrder < ModelBase
    include PlaceOS::Model::Timestamps

    table :asset_purchase_order

    attribute purchase_order_number : String, es_type: "keyword"
    attribute invoice_number : String?
    attribute supplier_details : JSON::Any?
    attribute purchase_date : Int64?

    attribute unit_price : Int64?
    attribute expected_service_start_date : Int64?
    attribute expected_service_end_date : Int64?

    has_many(
      child_class: Asset,
      foreign_key: "purchase_order_id",
      collection_name: :assets
    )

    # Validation
    ###############################################################################################

    validates :purchase_order_number, presence: true
  end
end
