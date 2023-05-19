require "./base/model"
require "./asset_category"

module PlaceOS::Model
  class AssetType < ModelWithAutoKey
    include PlaceOS::Model::Timestamps

    table :asset_type

    attribute name : String, es_subfield: "keyword"
    attribute brand : String
    attribute description : String?
    attribute model_number : String?
    attribute images : Array(String) = [] of String

    belongs_to AssetCategory, foreign_key: "category_id", association_name: "category", pk_type: Int64

    has_many(
      child_class: Asset,
      foreign_key: "asset_type_id",
      collection_name: :assets
    )
  end
end
