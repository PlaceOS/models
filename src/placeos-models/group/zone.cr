require "uuid"
require "uuid/json"

require "../base/model"
require "../group"
require "../permissions"
require "../zone"
require "./history"

module PlaceOS::Model
  # Junction table: a group's access to a zone, with a permission bitmask
  # and a `deny` flag. A row with `deny = true` masks off access that would
  # otherwise be inherited from an ancestor zone's GroupZone row (replace
  # semantics). Composite primary key `(group_id, zone_id)`.
  class GroupZone < ::PgORM::Base
    include PgORM::Timestamps

    table :group_zones

    primary_key :group_id, :zone_id

    attribute group_id : UUID
    belongs_to :group, class_name: Group, foreign_key: group_id

    attribute zone_id : String
    belongs_to :zone, class_name: Zone, foreign_key: zone_id

    attribute permissions : Int32 = 0
    attribute deny : Bool = false

    validates :group_id, presence: true
    validates :zone_id, presence: true

    include GroupHistory::Mixin

    def permission_flags : Permissions
      Permissions.new(self.permissions)
    end

    def permission_flags=(flags : Permissions)
      self.permissions = flags.to_i
    end

    protected def group_history_resource_id : String
      "#{self.group_id}:#{self.zone_id}"
    end

    protected def group_history_application_id : UUID?
      nil
    end

    protected def group_history_group_id : UUID?
      self.group_id
    end
  end
end
