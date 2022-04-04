require "json"
require "openapi-generator/serializable"

record(
  PlaceOS::Model::Version,
  service : String,
  commit : String,
  version : String,
  build_time : String,
  platform_version : String = {{ env("PLACE_VERSION") || "DEV" }},
) do
  include JSON::Serializable
  extend OpenAPI::Generator::Serializable
end
