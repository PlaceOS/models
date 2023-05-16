-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE "trig"
ALTER COLUMN control_system_id SET NOT NULL,
ALTER COLUMN trigger_id SET NOT NULL,

ADD CONSTRAINT fk_control_system
FOREIGN KEY (control_system_id)
REFERENCES sys(id)
ON DELETE CASCADE,

ADD CONSTRAINT fk_trigger
FOREIGN KEY (trigger_id)
REFERENCES trigger(id)
ON DELETE CASCADE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "trig"
DROP CONSTRAINT fk_control_system,
DROP CONSTRAINT fk_trigger,

ALTER COLUMN control_system_id DROP NOT NULL,
ALTER COLUMN trigger_id DROP NOT NULL;
