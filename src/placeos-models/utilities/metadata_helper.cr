require "rethinkdb-orm"

require "../metadata"

module PlaceOS::Model::Utilities
  module MetadataHelper
    def metadata(name : String? = nil) : Array(Metadata)
      Metadata.for(self, name)
    end
  end
end
