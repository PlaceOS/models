-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- ---------------------------------------------------------------------------
-- GroupPlaylists: presence-only M:N junction between Groups
-- (authority-scoped) and Playlists (authority-scoped, legacy TEXT PK).
-- A row = "this group has access to this playlist". The user's actual
-- capability on a row is the user's `GroupUser.permissions` within the
-- group — this junction does not carry its own bitmask.
--
-- Authority-match between `group` and `playlist` is enforced at the
-- model layer (the DB can't express it via a single FK).
--
-- "Playlists with zero junction rows are sys_admin/support-only" is a
-- REST-layer rule, not a DB invariant — the schema just allows zero or
-- more groups per playlist.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "group_playlists"(
    group_id UUID NOT NULL REFERENCES "groups"(id) ON DELETE CASCADE,
    playlist_id TEXT NOT NULL REFERENCES "playlists"(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (group_id, playlist_id)
);

CREATE INDEX IF NOT EXISTS group_playlists_playlist_id_index
    ON "group_playlists" USING BTREE (playlist_id);


-- ---------------------------------------------------------------------------
-- GroupPlaylistItems: same shape as group_playlists, but against
-- Playlist::Item rows (individual media / plugin / webpage items).
-- Items with no group junction rows are sys_admin/support-only
-- (enforced in the REST layer). As with group_playlists, the user's
-- capability is their GroupUser.permissions, not a per-row bitmask.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "group_playlist_items"(
    group_id UUID NOT NULL REFERENCES "groups"(id) ON DELETE CASCADE,
    playlist_item_id TEXT NOT NULL REFERENCES "playlist_items"(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (group_id, playlist_item_id)
);

CREATE INDEX IF NOT EXISTS group_playlist_items_playlist_item_id_index
    ON "group_playlist_items" USING BTREE (playlist_item_id);


-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP TABLE IF EXISTS "group_playlist_items";
DROP TABLE IF EXISTS "group_playlists";
