-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE mod ADD COLUMN IF NOT EXISTS launch_on_execute BOOLEAN NOT NULL DEFAULT FALSE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE mod DROP COLUMN IF EXISTS launch_on_execute;
