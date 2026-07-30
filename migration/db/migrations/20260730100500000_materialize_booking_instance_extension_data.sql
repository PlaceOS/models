-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Booking instance extension_data used to be stored as a sparse override and
-- merged with its parent when hydrated. Materialize that effective value now
-- so every non-empty instance object becomes a complete, replacement snapshot.
UPDATE "booking_instances" AS instance
SET extension_data = (
  CASE jsonb_typeof(parent.extension_data)
    WHEN 'object' THEN parent.extension_data
    ELSE '{}'::jsonb
  END
) || instance.extension_data
FROM "bookings" AS parent
WHERE parent.id = instance.id
  AND jsonb_typeof(instance.extension_data) = 'object'
  AND instance.extension_data <> '{}'::jsonb;

-- +micrate Down
-- This data migration is irreversible: after parent and instance keys are
-- combined, there is no reliable way to distinguish the former sparse
-- override from values inherited from the parent. Intentionally a no-op.
