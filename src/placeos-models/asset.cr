require "./base/model"

module PlaceOS::Model
  class Asset < ModelBase
    include RethinkORM::Timestamps

    table :asset

    attribute name : String, es_subfield: "keyword"
    attribute category : String = ""
    attribute description : String = ""

    attribute purchase_date : Time
    attribute good_until_date : Time?

    attribute barcode : String?
    attribute brand : String = ""

    # Saved as cents
    attribute purchase_price : Int32

    # Array of URLs to images for an asset
    attribute images : Array(String) = [] of String

    # URL of downloadable receipt
    attribute invoice : String?

    attribute quantity : Int32 = 0
    attribute in_use : Int32 = 0

    attribute other_data : JSON::Any = JSON::Any.new({} of String => JSON::Any), es_type: "object"

    attribute consumable_assets : Array(Asset)? = [] of Asset

    # Association
    ###############################################################################################

    has_many(
      child_class: AssetInstance,
      dependent: :destroy,
      foreign_key: "asset_id",
      collection_name: :asset_instances
    )

    has_many(
      child_class: Asset,
      foreign_key: "asset_id",
      collection_name: :assets
    )

    # Validation
    ###############################################################################################

    validates :quantity, numericality: {minimum: 0}
    validates :in_use, numericality: {minimum: 0}

    # Validate `in_use`
    validate ->(this : Asset) do
      this.validation_error(:in_use, "cannot use more assets than specified quantity") if this.in_use > this.quantity
    end
  end
end
