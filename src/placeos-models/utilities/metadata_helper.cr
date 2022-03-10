require "rethinkdb-orm"

require "../metadata"

module PlaceOS::Model::Utilities
  module MetadataHelper
    def master_metadata(name : String? = nil) : Array(Metadata)
      Metadata.for(self, name)
    end

    # Attain the metadata associated with the model
    #
    def metadata_collection
      RethinkORM::AssociationCollection(self.class, Metadata).new(self)
    end
  end
end
