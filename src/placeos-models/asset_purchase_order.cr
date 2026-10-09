require "./base/model"
require "./asset"

module PlaceOS::Model
  class AssetPurchaseOrder < ModelBase
    include PlaceOS::Model::Timestamps

    table :asset_purchase_order

    attribute purchase_order_number : String, sanitize: :text, es_type: "keyword"
    attribute invoice_number : String?, sanitize: :text
    attribute supplier_details : JSON::Any?, sanitize: :common
    attribute purchase_date : Int64?

    attribute unit_price : Int64?
    attribute expected_service_start_date : Int64?
    attribute expected_service_end_date : Int64?

    # NOTE: required (NOT NULL in the database). Nilable here so a controller can set it after
    # parsing a request body, see the presence validation below
    belongs_to Authority, foreign_key: "authority_id"

    # deleting a purchase order clears it from its assets (ON DELETE SET NULL)
    has_many(
      child_class: Asset,
      foreign_key: "purchase_order_id",
      collection_name: :assets
    )

    # Validation
    ###############################################################################################

    validates :purchase_order_number, :authority_id, presence: true
  end
end
