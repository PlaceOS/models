require "./base/model"
require "./asset_category"

module PlaceOS::Model
  class AssetType < ModelBase
    include PlaceOS::Model::Timestamps

    table :asset_type

    attribute name : String
    attribute brand : String
    attribute description : String?
    attribute model_number : String?
    attribute images : Array(String)?

    belongs_to AssetCategory, foreign_key: "category_id", association_name: "category"

    has_many(
      child_class: Asset,
      foreign_key: "asset_type_id",
      collection_name: :assets
    )
  end
end
