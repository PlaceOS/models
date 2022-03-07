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
      collection_name: "metadata",
      foreign_key: "schema_id",
    )
  end
end
