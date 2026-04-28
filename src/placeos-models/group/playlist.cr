require "uuid"
require "uuid/json"

require "../base/model"
require "../group"
require "../playlist"

module PlaceOS::Model
  # Junction between `Group` (authority-scoped, UUID) and `Playlist`
  # (authority-scoped, legacy TEXT PK). Lets groups co-own / share
  # playlists with each other within the same authority.
  #
  # Presence-only — no per-row permission bitmask, no GroupHistory
  # audit. A user's capability on a linked playlist comes from their
  # `GroupUser.permissions` within the group.
  #
  # Both sides must share an authority — enforced at the model layer
  # (no single FK can express it).
  class GroupPlaylist < ::PgORM::Base
    include PgORM::Timestamps

    table :group_playlists

    primary_key :group_id, :playlist_id

    attribute group_id : UUID
    belongs_to :group, class_name: Group, foreign_key: group_id

    attribute playlist_id : String
    belongs_to :playlist, class_name: Playlist, foreign_key: playlist_id

    validates :group_id, presence: true
    validates :playlist_id, presence: true

    validate ->(this : GroupPlaylist) {
      group = Group.find?(this.group_id)
      playlist = Playlist.find?(this.playlist_id)
      return if group.nil? || playlist.nil?
      return if group.authority_id == playlist.authority_id
      this.validation_error(:playlist_id, "must belong to the same authority as the group")
    }
  end
end
