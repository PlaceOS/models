require "./base/model"
require "./asset_type"

module PlaceOS::Model
  class AssetCategory < ModelWithAutoKey
    include PlaceOS::Model::Timestamps

    table :asset_category

    # i.e. a tablet
    attribute name : String, es_type: "keyword"
    attribute description : String?
    # attribute parent_category_id : Int64?

    belongs_to AssetCategory, foreign_key: "parent_category_id", association_name: "parent_category", pk_type: Int64

    has_many(
      child_class: AssetCategory,
      foreign_key: "parent_category_id",
      collection_name: :subcategories
    )

    has_many(
      child_class: AssetType,
      foreign_key: "category_id",
      collection_name: :asset_types
    )
  end
end
