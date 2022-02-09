require "random"

require "./base/model"

module PlaceOS::Model
  class Edge < ModelBase
    include RethinkORM::Timestamps

    table :edge

    attribute name : String, es_subfield: "keyword"

    attribute description : String = ""

    attribute api_key_id : String, presence: true, mass_assignment: false

    # Association
    ###############################################################################################

    # Modules allocated to this Edge
    has_many(
      child_class: Module,
      collection_name: "modules",
      foreign_key: "edge_id",
    )

    # Edges authenticate with an X-API-KEY
    has_one(
      child_class: ApiKey,
      dependent: :destroy,
      create_index: true,
      association_name: "api_key",
      presence: true,
    )

    # Validation
    ###############################################################################################

    ensure_unique :name do |name|
      name.strip
    end
  end
end
