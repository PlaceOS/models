require "rethinkdb-orm"

require "../user"

# Adds modification data to a `PlaceOS::Model`
module PlaceOS::Model::Utilities::LastModified
  macro included
    has_one User, association_name: :modified_by

    @modified_by : User?

    def modified_by=(user)
      previous_def(user).tap do
        modified_by_id_will_change!
      end
    end

    before_save :set_modified_by
    after_save :clear_modifier

    protected def set_modified_by
      unless self.modified_by_id_changed?
        Log.debug { "No modifying user recorded for #{self.id}" }
        self.modified_by_id = nil
      end
    end

    protected def clear_modifier
      @modified_by = nil
    end
  end
end
