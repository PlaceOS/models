-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE "chat_messages" ADD COLUMN IF NOT EXISTS tool_call_id TEXT;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE "chat_messages" DROP COLUMN IF EXISTS tool_call_id;
