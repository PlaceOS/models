require "uuid"
require "uuid/json"

require "../base/model"
require "../doorkeeper_application"
require "../group"
require "./history"

module PlaceOS::Model
  # Junction between a `GroupApplication` (permission subsystem) and a
  # `DoorkeeperApplication` (OAuth client). A single `GroupApplication`
  # can be reached by any of its linked OAuth apps; an OAuth app can
  # participate in more than one subsystem.
  #
  # Both sides must share an authority: `doorkeeper.owner_id` must equal
  # `group_application.authority_id`. Enforced here at the model layer
  # (no single FK can express it).
  class GroupApplicationDoorkeeper < ::PgORM::Base
    include PgORM::Timestamps

    table :group_application_doorkeepers

    primary_key :group_application_id, :doorkeeper_application_id

    attribute group_application_id : UUID
    belongs_to :group_application, class_name: GroupApplication, foreign_key: group_application_id

    attribute doorkeeper_application_id : Int64
    belongs_to :doorkeeper_application, class_name: DoorkeeperApplication, foreign_key: doorkeeper_application_id

    validates :group_application_id, presence: true
    validates :doorkeeper_application_id, presence: true

    validate ->(this : GroupApplicationDoorkeeper) {
      group_app = GroupApplication.find?(this.group_application_id)
      doorkeeper = DoorkeeperApplication.find?(this.doorkeeper_application_id)
      return if group_app.nil? || doorkeeper.nil?
      return if group_app.authority_id == doorkeeper.owner_id
      this.validation_error(
        :doorkeeper_application_id,
        "must belong to the same authority as the group application",
      )
    }

    include GroupHistory::Mixin

    protected def group_history_resource_id : String
      "#{self.group_application_id}:#{self.doorkeeper_application_id}"
    end

    protected def group_history_application_id : UUID?
      self.group_application_id
    end

    protected def group_history_group_id : UUID?
      nil
    end
  end
end
