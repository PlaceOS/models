-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
-- ---------------------------------------------------------------------------
-- PPT-526: an organisation flagged partner_staff is the partner's own staff
-- organisation. Its admins and support users administer every organisation
-- under that partner (partner reach), the way the management partner's staff
-- organisation administers the whole cluster.
-- ---------------------------------------------------------------------------
ALTER TABLE "organisations" ADD COLUMN IF NOT EXISTS partner_staff BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "organisations" DROP CONSTRAINT IF EXISTS organisations_partner_staff_needs_partner;
ALTER TABLE "organisations" ADD CONSTRAINT organisations_partner_staff_needs_partner
    CHECK (NOT partner_staff OR partner_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS organisations_partner_staff_index
    ON "organisations" USING BTREE (partner_id) WHERE partner_staff;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP INDEX IF EXISTS organisations_partner_staff_index;
ALTER TABLE "organisations" DROP CONSTRAINT IF EXISTS organisations_partner_staff_needs_partner;
ALTER TABLE "organisations" DROP COLUMN IF EXISTS partner_staff;
