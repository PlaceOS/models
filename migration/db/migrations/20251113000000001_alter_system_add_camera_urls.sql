-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS "timetable_url" TEXT NULL;
ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS "camera_url" TEXT NULL;
ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS "camera_snapshot_url" TEXT NULL;
ALTER TABLE "sys" ADD COLUMN IF NOT EXISTS "room_booking_url" TEXT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "sys" DROP COLUMN IF EXISTS "timetable_url";
ALTER TABLE "sys" DROP COLUMN IF EXISTS "camera_url";
ALTER TABLE "sys" DROP COLUMN IF EXISTS "camera_snapshot_url";
ALTER TABLE "sys" DROP COLUMN IF EXISTS "room_booking_url";
