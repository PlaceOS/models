-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Temporary function to transform work_preferences and work_overrides
CREATE 
OR REPLACE FUNCTION transform_work_preferences(preferences jsonb) RETURNS jsonb AS $$ 
DECLARE RESULT jsonb := '[]'::jsonb;
preference jsonb;
BEGIN
  FOR preference IN 
  SELECT
    * 
  FROM
    jsonb_array_elements(preferences) LOOP RESULT := RESULT || jsonb_build_object( 'day_of_week', 
    (
      preference ->> 'day_of_week'
    )
    ::INT, 'blocks', jsonb_build_array( jsonb_build_object( 'start_time', preference -> 'start_time', 'end_time', preference -> 'end_time', 'location', COALESCE(preference ->> 'location', '') ) ) );
END
LOOP;
RETURN RESULT;
END
;
$$ LANGUAGE plpgsql;

CREATE 
OR REPLACE FUNCTION transform_work_overrides(overrides jsonb) RETURNS jsonb AS $$ 
DECLARE RESULT jsonb := '{}'::jsonb;
DATE text;
override jsonb;
BEGIN
  FOR DATE,
  override IN 
  SELECT
    * 
  FROM
    jsonb_each(overrides) LOOP RESULT := RESULT || jsonb_build_object( DATE, 
    (
      SELECT
        transform_work_preferences(jsonb_build_array(override))
    )
    [0] );
END
LOOP;
RETURN RESULT;
END
;
$$ LANGUAGE plpgsql;

-- Update the work_preferences and work_overrides columns
UPDATE "user" SET work_preferences = transform_work_preferences(work_preferences);
UPDATE "user" SET work_overrides = transform_work_overrides(work_overrides);

-- Drop the temporary functions
DROP FUNCTION transform_work_preferences(jsonb);
DROP FUNCTION transform_work_overrides(jsonb);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

-- Temporary functions to revert work_preferences and work_overrides
CREATE OR REPLACE FUNCTION revert_work_preferences(preferences jsonb) RETURNS jsonb AS $$ 
DECLARE RESULT jsonb := '[]'::jsonb;
preference jsonb;
BEGIN
  FOR preference IN 
  SELECT
    * 
  FROM
    jsonb_array_elements(preferences) LOOP RESULT := RESULT || ( 
    SELECT
      jsonb_agg( jsonb_build_object( 'day_of_week', 
      (
        preference ->> 'day_of_week'
      )
      ::INT, 'start_time', block -> 'start_time', 'end_time', block -> 'end_time', 'location', COALESCE(block ->> 'location', '') ) ) 
    FROM
      jsonb_array_elements(preference -> 'blocks') AS block );
END
LOOP;
RETURN RESULT;
END
;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION revert_work_overrides(overrides jsonb) RETURNS jsonb AS $$ 
DECLARE RESULT jsonb := '{}'::jsonb;
DATE text;
override jsonb;
BEGIN
  FOR DATE,
  override IN 
  SELECT
    * 
  FROM
    jsonb_each(overrides) LOOP RESULT := RESULT || jsonb_build_object( DATE, 
    (
      SELECT
        revert_work_preferences(jsonb_build_array(override))
    )
    [0] );
END
LOOP;
RETURN RESULT;
END
;
$$ LANGUAGE plpgsql;

-- Revert the work_preferences column to its original format
UPDATE "user" SET work_preferences = revert_work_preferences(work_preferences);
UPDATE "user" SET work_overrides = revert_work_overrides(work_overrides);

-- Drop the temporary functions
DROP FUNCTION revert_work_preferences(jsonb);
DROP FUNCTION revert_work_overrides(jsonb);
