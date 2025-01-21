require "./base/model"
require "./asset_category"
require "./asset"

module PlaceOS::Model
  class AssetType < ModelBase
    include PlaceOS::Model::Timestamps

    table :asset_type

    attribute name : String, es_subfield: "keyword"
    attribute brand : String
    attribute description : String?
    attribute model_number : String?
    attribute images : Array(String)? = [] of String

    belongs_to AssetCategory, foreign_key: "category_id", association_name: "category"

    has_many(
      child_class: Asset,
      foreign_key: "asset_type_id",
      collection_name: :assets
    )

    # Validation
    ###############################################################################################

    validates :name, presence: true
    validates :brand, presence: true
    validates :category_id, presence: true

    # Metadata
    ###############################################################################################

    @[JSON::Field(ignore_deserialize: true)]
    property asset_count : Int64 { Asset.where(asset_type_id: self.id).count }

    def to_json(json : ::JSON::Builder)
      asset_count
      super
    end
  end
end
