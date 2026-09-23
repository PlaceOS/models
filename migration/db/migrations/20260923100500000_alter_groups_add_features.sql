-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Per-subsystem feature flags / display config, keyed by subsystem code:
-- {"signage": {"templates": true, "plugins": ["..."]}}. Child groups inherit
-- their ancestors' features and may override individual keys.
ALTER TABLE "groups" ADD COLUMN IF NOT EXISTS features JSONB NOT NULL DEFAULT '{}';

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "groups" DROP COLUMN IF EXISTS features;
