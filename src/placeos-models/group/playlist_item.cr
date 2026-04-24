require "uuid"
require "uuid/json"

require "../base/model"
require "../group"
require "../playlist/item"

module PlaceOS::Model
  # Junction between `Group` (authority-scoped, UUID) and
  # `Playlist::Item` (authority-scoped, legacy TEXT PK). Same M:N shape
  # as `GroupPlaylist` but against individual media / plugin / webpage
  # items.
  #
  # Presence-only — no per-row permission bitmask, no GroupHistory
  # audit. A user's capability on a linked item comes from their
  # `GroupUser.permissions` within the group.
  #
  # Both sides must share an authority — enforced here at the model
  # layer (no single FK can express it).
  class GroupPlaylistItem < ::PgORM::Base
    include PgORM::Timestamps

    table :group_playlist_items

    primary_key :group_id, :playlist_item_id

    attribute group_id : UUID
    belongs_to :group, class_name: Group, foreign_key: group_id

    attribute playlist_item_id : String
    belongs_to :playlist_item, class_name: Playlist::Item, foreign_key: playlist_item_id

    validates :group_id, presence: true
    validates :playlist_item_id, presence: true

    validate ->(this : GroupPlaylistItem) {
      group = Group.find?(this.group_id)
      item = Playlist::Item.find?(this.playlist_item_id)
      return if group.nil? || item.nil?
      return if group.authority_id == item.authority_id
      this.validation_error(:playlist_item_id, "must belong to the same authority as the group")
    }
  end
end
