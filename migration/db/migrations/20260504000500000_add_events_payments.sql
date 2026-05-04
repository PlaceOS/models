-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- +micrate StatementBegin
DO
$$
BEGIN
  IF NOT EXISTS (
    SELECT *
    FROM pg_type typ
           INNER JOIN pg_namespace nsp ON nsp.oid = typ.typnamespace
    WHERE nsp.nspname = current_schema()
      AND typ.typname = 'rate_card_kind'
  ) THEN
    CREATE TYPE rate_card_kind AS ENUM ('BASE', 'ADJUSTMENT');
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

-- +micrate StatementBegin
DO
$$
BEGIN
  IF NOT EXISTS (
    SELECT *
    FROM pg_type typ
           INNER JOIN pg_namespace nsp ON nsp.oid = typ.typnamespace
    WHERE nsp.nspname = current_schema()
      AND typ.typname = 'customer_type'
  ) THEN
    CREATE TYPE customer_type AS ENUM ('INTERNAL', 'EXTERNAL', 'STUDENT', 'PARTNER');
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

-- +micrate StatementBegin
DO
$$
BEGIN
  IF NOT EXISTS (
    SELECT *
    FROM pg_type typ
           INNER JOIN pg_namespace nsp ON nsp.oid = typ.typnamespace
    WHERE nsp.nspname = current_schema()
      AND typ.typname = 'day_type'
  ) THEN
    CREATE TYPE day_type AS ENUM ('WEEKDAY', 'WEEKEND', 'PUBLIC_HOLIDAY');
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

-- +micrate StatementBegin
DO
$$
BEGIN
  IF NOT EXISTS (
    SELECT *
    FROM pg_type typ
           INNER JOIN pg_namespace nsp ON nsp.oid = typ.typnamespace
    WHERE nsp.nspname = current_schema()
      AND typ.typname = 'charge_basis'
  ) THEN
    CREATE TYPE charge_basis AS ENUM (
      'FIXED',
      'PER_BOOKING',
      'PER_HALF_DAY',
      'PER_FULL_DAY',
      'PER_HOUR',
      'PER_ATTENDEE',
      'PERCENTAGE'
    );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

-- +micrate StatementBegin
DO
$$
BEGIN
  IF NOT EXISTS (
    SELECT *
    FROM pg_type typ
           INNER JOIN pg_namespace nsp ON nsp.oid = typ.typnamespace
    WHERE nsp.nspname = current_schema()
      AND typ.typname = 'charge_category'
  ) THEN
    CREATE TYPE charge_category AS ENUM (
      'VENUE_HIRE',
      'ASSET_HIRE',
      'SURCHARGE',
      'DISCOUNT',
      'OTHER'
    );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

-- +micrate StatementBegin
DO
$$
BEGIN
  IF NOT EXISTS (
    SELECT *
    FROM pg_type typ
           INNER JOIN pg_namespace nsp ON nsp.oid = typ.typnamespace
    WHERE nsp.nspname = current_schema()
      AND typ.typname = 'quote_status'
  ) THEN
    CREATE TYPE quote_status AS ENUM ('DRAFT', 'ACCEPTED', 'SUPERSEDED', 'CANCELLED');
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

-- +micrate StatementBegin
DO
$$
BEGIN
  IF NOT EXISTS (
    SELECT *
    FROM pg_type typ
           INNER JOIN pg_namespace nsp ON nsp.oid = typ.typnamespace
    WHERE nsp.nspname = current_schema()
      AND typ.typname = 'payment_status'
  ) THEN
    CREATE TYPE payment_status AS ENUM ('PENDING', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'REFUNDED', 'VOIDED');
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

-- +micrate StatementBegin
DO
$$
BEGIN
  IF NOT EXISTS (
    SELECT *
    FROM pg_type typ
           INNER JOIN pg_namespace nsp ON nsp.oid = typ.typnamespace
    WHERE nsp.nspname = current_schema()
      AND typ.typname = 'payment_method'
  ) THEN
    CREATE TYPE payment_method AS ENUM ('UNKNOWN', 'CASH', 'CARD', 'BANK_TRANSFER', 'ONLINE');
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

CREATE TABLE IF NOT EXISTS "rate_cards"(
  id UUID PRIMARY KEY DEFAULT uuidv7(),

  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',

  kind public.rate_card_kind NOT NULL DEFAULT 'BASE'::public.rate_card_kind,
  priority INTEGER NOT NULL DEFAULT 100,

  valid_from TIMESTAMPTZ,
  valid_to TIMESTAMPTZ,

  currency TEXT NOT NULL DEFAULT 'AUD',
  active BOOLEAN NOT NULL DEFAULT TRUE,

  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,

  CONSTRAINT rate_cards_valid_date_range_check CHECK (
    valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from
  )
);

CREATE INDEX IF NOT EXISTS rate_cards_active_idx ON "rate_cards" USING BTREE (active);
CREATE INDEX IF NOT EXISTS rate_cards_kind_idx ON "rate_cards" USING BTREE (kind);
CREATE INDEX IF NOT EXISTS rate_cards_validity_idx ON "rate_cards" USING BTREE (valid_from, valid_to);

CREATE TABLE IF NOT EXISTS "rate_card_assignments"(
  id UUID PRIMARY KEY DEFAULT uuidv7(),

  rate_card_id UUID NOT NULL REFERENCES "rate_cards"(id) ON DELETE CASCADE,

  asset_type_id TEXT REFERENCES "asset_type"(id) ON DELETE CASCADE,
  asset_id TEXT REFERENCES "asset"(id) ON DELETE CASCADE,
  space_id TEXT REFERENCES "sys"(id) ON DELETE CASCADE,
  site_id TEXT REFERENCES "zone"(id) ON DELETE CASCADE,

  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,

  CONSTRAINT rate_card_assignments_single_target_check CHECK (
    num_nonnulls(asset_type_id, asset_id, space_id, site_id) = 1
  )
);

CREATE INDEX IF NOT EXISTS rate_card_assignments_rate_card_id_idx ON "rate_card_assignments" USING BTREE (rate_card_id);
CREATE INDEX IF NOT EXISTS rate_card_assignments_asset_type_id_idx ON "rate_card_assignments" USING BTREE (asset_type_id);
CREATE INDEX IF NOT EXISTS rate_card_assignments_asset_id_idx ON "rate_card_assignments" USING BTREE (asset_id);
CREATE INDEX IF NOT EXISTS rate_card_assignments_space_id_idx ON "rate_card_assignments" USING BTREE (space_id);
CREATE INDEX IF NOT EXISTS rate_card_assignments_site_id_idx ON "rate_card_assignments" USING BTREE (site_id);

CREATE UNIQUE INDEX IF NOT EXISTS rate_card_assignments_unique_asset_type_idx
  ON "rate_card_assignments" (rate_card_id, asset_type_id)
  WHERE asset_type_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS rate_card_assignments_unique_asset_idx
  ON "rate_card_assignments" (rate_card_id, asset_id)
  WHERE asset_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS rate_card_assignments_unique_space_idx
  ON "rate_card_assignments" (rate_card_id, space_id)
  WHERE space_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS rate_card_assignments_unique_site_idx
  ON "rate_card_assignments" (rate_card_id, site_id)
  WHERE site_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS "duration_bands"(
  id UUID PRIMARY KEY DEFAULT uuidv7(),

  rate_card_id UUID NOT NULL REFERENCES "rate_cards"(id) ON DELETE CASCADE,

  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',

  min_minutes INTEGER NOT NULL,
  max_minutes INTEGER,

  priority INTEGER NOT NULL DEFAULT 100,
  active BOOLEAN NOT NULL DEFAULT TRUE,

  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,

  CONSTRAINT duration_bands_min_minutes_check CHECK (min_minutes >= 0),
  CONSTRAINT duration_bands_max_minutes_check CHECK (max_minutes IS NULL OR max_minutes >= min_minutes),
  CONSTRAINT duration_bands_name_per_rate_card_unique UNIQUE (rate_card_id, name)
);

CREATE INDEX IF NOT EXISTS duration_bands_rate_card_id_idx ON "duration_bands" USING BTREE (rate_card_id);
CREATE INDEX IF NOT EXISTS duration_bands_active_idx ON "duration_bands" USING BTREE (active);
CREATE INDEX IF NOT EXISTS duration_bands_duration_idx ON "duration_bands" USING BTREE (min_minutes, max_minutes);

CREATE TABLE IF NOT EXISTS "pricing_rules"(
  id UUID PRIMARY KEY DEFAULT uuidv7(),

  rate_card_id UUID NOT NULL REFERENCES "rate_cards"(id) ON DELETE CASCADE,
  duration_band_id UUID REFERENCES "duration_bands"(id) ON DELETE SET NULL,

  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',

  charge_category public.charge_category NOT NULL,
  charge_basis public.charge_basis NOT NULL,

  amount_cents INTEGER NOT NULL,

  customer_type public.customer_type,
  day_type public.day_type,

  min_attendees INTEGER,
  max_attendees INTEGER,

  priority INTEGER NOT NULL DEFAULT 100,
  stackable BOOLEAN NOT NULL DEFAULT FALSE,
  active BOOLEAN NOT NULL DEFAULT TRUE,

  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,

  CONSTRAINT pricing_rules_attendee_range_check CHECK (
    min_attendees IS NULL OR max_attendees IS NULL OR max_attendees >= min_attendees
  ),

  CONSTRAINT pricing_rules_min_attendees_check CHECK (
    min_attendees IS NULL OR min_attendees >= 0
  ),

  CONSTRAINT pricing_rules_max_attendees_check CHECK (
    max_attendees IS NULL OR max_attendees >= 0
  )
);

CREATE INDEX IF NOT EXISTS pricing_rules_rate_card_id_idx ON "pricing_rules" USING BTREE (rate_card_id);
CREATE INDEX IF NOT EXISTS pricing_rules_duration_band_id_idx ON "pricing_rules" USING BTREE (duration_band_id);
CREATE INDEX IF NOT EXISTS pricing_rules_active_idx ON "pricing_rules" USING BTREE (active);
CREATE INDEX IF NOT EXISTS pricing_rules_match_idx
  ON "pricing_rules" USING BTREE (rate_card_id, customer_type, day_type, charge_category, active);
CREATE INDEX IF NOT EXISTS pricing_rules_priority_idx ON "pricing_rules" USING BTREE (priority);

CREATE TABLE IF NOT EXISTS "booking_quotes"(
  id UUID PRIMARY KEY DEFAULT uuidv7(),

  booking_id BIGINT NOT NULL REFERENCES "bookings"(id) ON DELETE CASCADE,

  rate_card_id UUID REFERENCES "rate_cards"(id) ON DELETE SET NULL,

  status public.quote_status NOT NULL DEFAULT 'DRAFT'::public.quote_status,

  subtotal_cents INTEGER NOT NULL DEFAULT 0,
  tax_cents INTEGER NOT NULL DEFAULT 0,
  total_cents INTEGER NOT NULL DEFAULT 0,

  currency TEXT NOT NULL DEFAULT 'AUD',

  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,

  CONSTRAINT booking_quotes_amounts_check CHECK (
    subtotal_cents >= 0 AND tax_cents >= 0 AND total_cents >= 0
  )
);

CREATE INDEX IF NOT EXISTS booking_quotes_booking_id_idx ON "booking_quotes" USING BTREE (booking_id);
CREATE INDEX IF NOT EXISTS booking_quotes_rate_card_id_idx ON "booking_quotes" USING BTREE (rate_card_id);
CREATE INDEX IF NOT EXISTS booking_quotes_status_idx ON "booking_quotes" USING BTREE (status);
CREATE INDEX IF NOT EXISTS booking_quotes_created_at_idx ON "booking_quotes" USING BTREE (created_at);

CREATE TABLE IF NOT EXISTS "rate_card_history"(
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  rate_card_id UUID NOT NULL,
  user_id TEXT REFERENCES "user"(id) ON DELETE SET NULL,
  email TEXT NOT NULL,
  action TEXT NOT NULL,
  changed_fields TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS rate_card_history_rate_card_id_idx ON "rate_card_history" USING BTREE (rate_card_id);
CREATE INDEX IF NOT EXISTS rate_card_history_user_id_idx ON "rate_card_history" USING BTREE (user_id);
CREATE INDEX IF NOT EXISTS rate_card_history_created_at_idx ON "rate_card_history" USING BTREE (created_at);

CREATE TABLE IF NOT EXISTS "booking_quote_history"(
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  quote_id UUID NOT NULL,
  user_id TEXT REFERENCES "user"(id) ON DELETE SET NULL,
  email TEXT NOT NULL,
  action TEXT NOT NULL,
  changed_fields TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS booking_quote_history_quote_id_idx ON "booking_quote_history" USING BTREE (quote_id);
CREATE INDEX IF NOT EXISTS booking_quote_history_user_id_idx ON "booking_quote_history" USING BTREE (user_id);
CREATE INDEX IF NOT EXISTS booking_quote_history_created_at_idx ON "booking_quote_history" USING BTREE (created_at);

CREATE TABLE IF NOT EXISTS "booking_quote_line_items"(
  id UUID PRIMARY KEY DEFAULT uuidv7(),

  quote_id UUID NOT NULL REFERENCES "booking_quotes"(id) ON DELETE CASCADE,

  pricing_rule_id UUID REFERENCES "pricing_rules"(id) ON DELETE SET NULL,

  description TEXT NOT NULL,

  charge_category public.charge_category NOT NULL,
  charge_basis public.charge_basis NOT NULL,

  quantity NUMERIC(12, 4) NOT NULL DEFAULT 1,

  unit_amount_cents INTEGER NOT NULL,
  total_amount_cents INTEGER NOT NULL,

  approved BOOLEAN NOT NULL DEFAULT FALSE,

  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,

  CONSTRAINT booking_quote_line_items_quantity_check CHECK (quantity >= 0)
);

CREATE INDEX IF NOT EXISTS booking_quote_line_items_quote_id_idx ON "booking_quote_line_items" USING BTREE (quote_id);
CREATE INDEX IF NOT EXISTS booking_quote_line_items_pricing_rule_id_idx ON "booking_quote_line_items" USING BTREE (pricing_rule_id);
CREATE INDEX IF NOT EXISTS booking_quote_line_items_charge_category_idx ON "booking_quote_line_items" USING BTREE (charge_category);
CREATE INDEX IF NOT EXISTS booking_quote_line_items_approved_idx ON "booking_quote_line_items" USING BTREE (approved);

CREATE TABLE IF NOT EXISTS "booking_payments"(
  id UUID PRIMARY KEY DEFAULT uuidv7(),

  quote_id UUID NOT NULL REFERENCES "booking_quotes"(id) ON DELETE CASCADE,
  booking_id BIGINT NOT NULL REFERENCES "bookings"(id) ON DELETE CASCADE,

  amount_cents INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'AUD',

  status public.payment_status NOT NULL DEFAULT 'PENDING'::public.payment_status,
  payment_method public.payment_method NOT NULL DEFAULT 'UNKNOWN'::public.payment_method,

  provider TEXT,
  reference TEXT,
  paid_at TIMESTAMPTZ,

  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,

  CONSTRAINT booking_payments_amount_cents_check CHECK (amount_cents >= 0)
);

CREATE INDEX IF NOT EXISTS booking_payments_quote_id_idx ON "booking_payments" USING BTREE (quote_id);
CREATE INDEX IF NOT EXISTS booking_payments_booking_id_idx ON "booking_payments" USING BTREE (booking_id);
CREATE INDEX IF NOT EXISTS booking_payments_status_idx ON "booking_payments" USING BTREE (status);
CREATE INDEX IF NOT EXISTS booking_payments_paid_at_idx ON "booking_payments" USING BTREE (paid_at);
CREATE UNIQUE INDEX IF NOT EXISTS booking_payments_reference_unique_idx
  ON "booking_payments" (reference)
  WHERE reference IS NOT NULL;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE IF EXISTS "booking_quote_history";
DROP TABLE IF EXISTS "rate_card_history";
DROP TABLE IF EXISTS "booking_payments";
DROP TABLE IF EXISTS "booking_quote_line_items";
DROP TABLE IF EXISTS "booking_quotes";
DROP TABLE IF EXISTS "pricing_rules";
DROP TABLE IF EXISTS "duration_bands";
DROP TABLE IF EXISTS "rate_card_assignments";
DROP TABLE IF EXISTS "rate_cards";

DROP TYPE IF EXISTS public.payment_method;
DROP TYPE IF EXISTS public.payment_status;
DROP TYPE IF EXISTS public.quote_status;
DROP TYPE IF EXISTS public.charge_category;
DROP TYPE IF EXISTS public.charge_basis;
DROP TYPE IF EXISTS public.day_type;
DROP TYPE IF EXISTS public.customer_type;
DROP TYPE IF EXISTS public.rate_card_kind;
