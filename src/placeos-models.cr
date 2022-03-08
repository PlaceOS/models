require "./ext/*"

require "log"
require "rethinkdb-orm"

require "./placeos-models/base/*"

module PlaceOS::Model
  Log = ::Log.for(self)

  # Expose RethinkDB connection
  # Use for configuration, raw queries
  class Connection < RethinkORM::Connection
  end
end

require "./placeos-models/*"
