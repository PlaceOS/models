require "rethinkdb-orm"

require "../user"

module PlaceOS::Model::Utilities::LastModified
  macro included
    attribute modified_at : Time = ->{ Time.utc }, converter: Time::EpochConverter

    has_one User, association_name: :modified_by, presence: true

    before_save :set_modified_by

    macro finished
      def modified_by=(user)
        previous_def(user).tap do
          modified_by_id_will_change!
        end
      end
    end

    protected def set_modified_by
      raise Model::Error.new("Modifying user not recorded") unless modified_by_id_changed?
      self.modified_at = Time.utc
    end
  end
end
