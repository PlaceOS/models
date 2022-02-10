require "active-model"
require "json"
require "log"
require "neuroplastic"
require "rethinkdb-orm"

require "openapi-generator"
require "openapi-generator/serializable"
require "openapi-generator/serializable/adapters/active-model"

require "../utilities/encryption"
require "../utilities/validation"

module PlaceOS::Model
  # Base class for all Engine models
  abstract class ModelBase < RethinkORM::Base
    include Neuroplastic

    macro inherited
      Log = ::Log.for(self)
      include OpenAPI::Generator::Serializable::Adapters::ActiveModel
    end
  end

  # Validation for embedded objects in Engine models
  abstract class SubModel < ActiveModel::Model
    include ActiveModel::Validation

    macro inherited
      Log = ::Log.for(self)
      include OpenAPI::Generator::Serializable::Adapters::ActiveModel
    end

    # RethinkDB library serializes through JSON::Any
    def to_reql
      JSON.parse(self.to_json)
    end

    # Propagate submodel validation errors to parent's
    protected def collect_errors(collection : Symbol, models)
      errors = models.compact_map do |m|
        m.errors unless m.valid?
      end

      errors.flatten.each do |e|
        validation_error(field: collection, message: e.to_s)
      end
    end
  end
end
