require "uuid"
require "uuid/json"

require "../base/model"
require "../group"
require "../signage_template"

module PlaceOS::Model
  # Junction between `Group` and `SignageTemplate` (both authority-scoped,
  # UUID). Same M:N shape as `GroupPlaylistItem` — allows templates to be
  # shared with groups so they can manage their own templates.
  #
  # Presence-only — no per-row permission bitmask, no GroupHistory audit.
  # A user's capability on a linked template comes from their
  # `GroupUser.permissions` within the group.
  #
  # Both sides must share an authority — enforced here at the model layer
  # (no single FK can express it).
  class GroupSignageTemplate < ::PgORM::Base
    include PgORM::Timestamps

    table :group_signage_templates

    primary_key :group_id, :signage_template_id

    attribute group_id : UUID
    belongs_to :group, class_name: Group, foreign_key: group_id

    attribute signage_template_id : UUID
    belongs_to :signage_template, class_name: SignageTemplate, foreign_key: signage_template_id

    validates :group_id, presence: true
    validates :signage_template_id, presence: true

    validate ->(this : GroupSignageTemplate) {
      group = Group.find?(this.group_id)
      template = SignageTemplate.find?(this.signage_template_id)
      return if group.nil? || template.nil?
      return if group.authority_id == template.authority_id
      this.validation_error(:signage_template_id, "must belong to the same authority as the group")
    }
  end
end
