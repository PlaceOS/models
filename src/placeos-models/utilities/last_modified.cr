require "rethinkdb-orm"

require "../user"

module PlaceOS::Model::Utilities::LastModified
  macro included
    @[YAML::Field(ignore: true)]
    @[JSON::Field(ignore: true)]
    property last_modified_by : Model::User? = nil

    attribute modified_at : Time = ->{ Time.utc }, converter: Time::EpochConverter

    belongs_to User, association_name: :modified_by, presence: true

    before_save :set_modification

    protected def set_modification
      if (modifying_user = last_modified_by).nil?
        raise Error.new("modifying user not recorded")
      end

      self.modified_at = Time.utc
      self.modified_by = modifying_user
    end
  end
end
