-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS camera_snapshot_urls TEXT[] DEFAULT '{}';
UPDATE "sys" SET camera_snapshot_urls[1] = camera_snapshot_url WHERE camera_snapshot_url IS NOT NULL;

ALTER TABLE "driver" ADD COLUMN IF NOT EXISTS alert_level public.alert_severity NOT NULL DEFAULT 'MEDIUM'::public.alert_severity;
ALTER TABLE "mod" ADD COLUMN IF NOT EXISTS alert_level public.alert_severity NOT NULL DEFAULT 'MEDIUM'::public.alert_severity;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "driver" DROP COLUMN IF EXISTS alert_level;
ALTER TABLE "mod" DROP COLUMN IF EXISTS alert_level;
ALTER TABLE "sys" DROP COLUMN IF EXISTS camera_snapshot_urls;
