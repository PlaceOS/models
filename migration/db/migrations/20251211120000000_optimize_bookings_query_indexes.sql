-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Drop the existing HASH index on tenant_id and replace with BTREE for better range query support
DROP INDEX IF EXISTS bookings_tenant_id_idx;
CREATE INDEX IF NOT EXISTS bookings_tenant_id_btree_idx ON bookings USING BTREE (tenant_id);

-- Create a composite index for the most common query pattern:
-- tenant_id + booking_type + deleted + time range queries
CREATE INDEX IF NOT EXISTS bookings_tenant_type_deleted_time_idx 
  ON bookings USING BTREE (tenant_id, booking_type, deleted, booking_start, booking_end)
  WHERE deleted = FALSE;

-- Create a GIN index for zones array with additional conditions
-- This helps with the "ANY (zones)" queries
CREATE INDEX IF NOT EXISTS bookings_zones_gin_idx 
  ON bookings USING GIN (zones)
  WHERE deleted = FALSE AND checked_out_at IS NULL;

-- Create a composite index for recurring bookings queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS bookings_recurring_idx
  ON bookings (tenant_id, booking_start, recurrence_end)
  WHERE recurrence_type <> 'NONE';

-- Create a composite index for regular (non-recurring) bookings time range queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS bookings_regular_time_idx
  ON bookings (tenant_id, booking_start, booking_end)
  WHERE recurrence_type = 'NONE';

-- Create a partial index for active bookings (not checked out, not deleted)
CREATE INDEX IF NOT EXISTS bookings_active_idx
  ON bookings USING BTREE (tenant_id, booking_type, booking_start, booking_end)
  WHERE deleted = FALSE AND checked_out_at IS NULL;

-- Create a composite index specifically for the zone + type + time range query pattern
CREATE INDEX IF NOT EXISTS bookings_tenant_type_time_zones_idx
  ON bookings USING BTREE (tenant_id, booking_type, booking_start, booking_end)
  INCLUDE (zones, recurrence_type, recurrence_end, rejected_at, deleted_at, checked_out_at)
  WHERE deleted = FALSE;

-- Create a composite index for deleted bookings queries (mirrors the non-deleted index)
CREATE INDEX IF NOT EXISTS bookings_deleted_lookup_idx
  ON bookings USING BTREE (tenant_id, booking_type, booking_start, booking_end)
  INCLUDE (zones, recurrence_type, recurrence_end, rejected_at, deleted_at, checked_out_at)
  WHERE deleted = TRUE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP INDEX IF EXISTS bookings_deleted_lookup_idx;
DROP INDEX IF EXISTS bookings_tenant_type_time_zones_idx;
DROP INDEX IF EXISTS bookings_active_idx;
DROP INDEX IF EXISTS bookings_regular_time_idx;
DROP INDEX IF EXISTS bookings_recurring_idx;
DROP INDEX IF EXISTS bookings_zones_gin_idx;
DROP INDEX IF EXISTS bookings_tenant_type_deleted_time_idx;
DROP INDEX IF EXISTS bookings_tenant_id_btree_idx;

-- Restore the original HASH index
CREATE INDEX IF NOT EXISTS bookings_tenant_id_idx ON bookings USING HASH (tenant_id);
