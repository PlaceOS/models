require "uuid"
require "uuid/json"

require "../base/model"
require "../group"
require "../permissions"
require "../user"
require "./history"

module PlaceOS::Model
  # Junction table: a user's membership in a group, with a permission
  # bitmask. Composite primary key `(user_id, group_id)`.
  class GroupUser < ::PgORM::Base
    include PgORM::Timestamps

    table :group_users

    primary_key :user_id, :group_id

    attribute user_id : String
    belongs_to :user, class_name: User, foreign_key: user_id

    attribute group_id : UUID
    belongs_to :group, class_name: Group, foreign_key: group_id

    # Stored as an Int32 bitmask. Use `permission_flags` / `permission_flags=`
    # when working with the `Permissions` flags enum directly.
    attribute permissions : Int32 = 0

    validates :user_id, presence: true
    validates :group_id, presence: true

    validate ->(this : GroupUser) {
      user = User.find?(this.user_id)
      group = Group.find?(this.group_id)
      return if user.nil? || group.nil?
      return if user.authority_id == group.authority_id
      this.validation_error(:user_id, "must belong to the same authority as the group")
    }

    include GroupHistory::Mixin

    def permission_flags : Permissions
      Permissions.new(self.permissions)
    end

    def permission_flags=(flags : Permissions)
      self.permissions = flags.to_i
    end

    protected def group_history_resource_id : String
      "#{self.user_id}:#{self.group_id}"
    end

    protected def group_history_application_id : UUID?
      nil
    end

    protected def group_history_group_id : UUID?
      self.group_id
    end
  end
end
