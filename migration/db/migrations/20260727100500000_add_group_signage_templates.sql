-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- GroupSignageTemplates: same shape as group_playlist_items, but against
-- signage_template rows. Templates with no group junction rows are
-- sys_admin/support-only (enforced in the REST layer). The user's
-- capability is their GroupUser.permissions, not a per-row bitmask.
CREATE TABLE IF NOT EXISTS "group_signage_templates"(
    group_id UUID NOT NULL REFERENCES "groups"(id) ON DELETE CASCADE,
    signage_template_id UUID NOT NULL REFERENCES "signage_template"(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (group_id, signage_template_id)
);

CREATE INDEX IF NOT EXISTS group_signage_templates_signage_template_id_index
    ON "group_signage_templates" USING BTREE (signage_template_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP TABLE IF EXISTS "group_signage_templates";
