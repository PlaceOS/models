require "./base/model"
require "./asset_type"

module PlaceOS::Model
  class AssetCategory < ModelBase
    include PlaceOS::Model::Timestamps

    table :asset_category

    # i.e. a tablet
    attribute name : String, sanitize: :text, es_subfield: "keyword"
    # NOTE: intentionally not sanitized — this field is used to hold raw JSON
    # strings (e.g. `{"resource_type":"locker_banks",...}`) and an HTML
    # sanitizer would mangle characters such as `"` and `&`. See the
    # "preserves a JSON string stored in the description field" spec.
    attribute description : String?
    attribute hidden : Bool = false, es_subfield: "keyword"

    belongs_to AssetCategory, foreign_key: "parent_category_id", association_name: "parent_category"

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

    # Validation
    ###############################################################################################

    validates :name, presence: true
  end
end
