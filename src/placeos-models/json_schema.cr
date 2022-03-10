require "./base/model"
require "./converter/json_string"

module PlaceOS::Model
  class JsonSchema < ModelBase
    include RethinkORM::Timestamps

    table :json_schema

    attribute name : String, es_subfield: "keyword"
    attribute description : String = ""
    attribute schema : JSON::Any = JSON::Any.new({} of String => JSON::Any), converter: JSON::Any::StringConverter, es_type: "text"

    has_many(
      child_class: Metadata,
      collection_name: "metadata_and_versions",
      foreign_key: "schema_id",
    )

    def metadata
      Metadata.master_metadata_query do |q|
        q.filter({schema_id: self.id.as(String)})
      end
    end
  end
end
