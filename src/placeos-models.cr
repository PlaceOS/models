require "pg-orm"
require "./ext/*"

require "log"
require "./placeos-models/base/*"

module PlaceOS::Model
  Log = ::Log.for(self)

  # class Connection < RethinkORM::Connection
  # end
end

require "./placeos-models/*"
