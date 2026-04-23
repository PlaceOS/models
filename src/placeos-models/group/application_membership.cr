require "uuid"
require "uuid/json"

require "../base/model"
require "../group"
require "./history"

module PlaceOS::Model
  # Junction between `Group` (authority-scoped) and `GroupApplication`.
  # Each row makes a group a participant in an application — only grants
  # attached to groups in the application's membership list affect that
  # application's permission queries.
  #
  # Both sides must share an authority. Enforced here at the model layer
  # (the database can't express it as a single FK).
  class GroupApplicationMembership < ::PgORM::Base
    include PgORM::Timestamps

    table :group_application_memberships

    primary_key :group_id, :application_id

    attribute group_id : UUID
    belongs_to :group, class_name: Group, foreign_key: group_id

    attribute application_id : UUID
    belongs_to :application, class_name: GroupApplication, foreign_key: application_id

    validates :group_id, presence: true
    validates :application_id, presence: true

    validate ->(this : GroupApplicationMembership) {
      group = Group.find?(this.group_id)
      application = GroupApplication.find?(this.application_id)
      return if group.nil? || application.nil?
      return if group.authority_id == application.authority_id
      this.validation_error(:application_id, "must belong to the same authority as the group")
    }

    include GroupHistory::Mixin

    protected def group_history_resource_id : String
      "#{self.group_id}:#{self.application_id}"
    end

    protected def group_history_application_id : UUID?
      self.application_id
    end

    protected def group_history_group_id : UUID?
      self.group_id
    end
  end
end
