-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Table for model PlaceOS::Model::Chat
CREATE TABLE IF NOT EXISTS "chats"(
   id TEXT NOT NULL PRIMARY KEY,
   user_id TEXT NOT NULL,
   system_id TEXT NOT NULL,
   summary TEXT NOT NULL,
   created_at TIMESTAMPTZ NOT NULL,
   updated_at TIMESTAMPTZ NOT NULL   
);

CREATE INDEX IF NOT EXISTS chats_user_id_index ON "chats" USING BTREE (user_id);
CREATE INDEX IF NOT EXISTS chats_system_id_index ON "chats" USING BTREE (system_id);
CREATE INDEX IF NOT EXISTS chats_summary_index ON "chats" USING BTREE (summary);

-- Table for model PlaceOS::Model::ChatMessage
CREATE TABLE IF NOT EXISTS "chat_messages"(
   id bigint PRIMARY KEY,
   chat_id TEXT NOT NULL,
   role INTEGER NOT NULL,
   content TEXT ,
   function_name TEXT,
   function_args JSONB,
   created_at TIMESTAMPTZ NOT NULL,
   updated_at TIMESTAMPTZ NOT NULL   
);


CREATE SEQUENCE IF NOT EXISTS public.chat_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.chat_messages_id_seq OWNED BY "chat_messages".id;
ALTER TABLE ONLY "chat_messages" ALTER COLUMN id SET DEFAULT nextval('public.chat_messages_id_seq'::regclass);

CREATE INDEX IF NOT EXISTS chat_messages_chat_id_index ON "chat_messages" USING BTREE (chat_id);
CREATE INDEX IF NOT EXISTS chat_messages_role_index ON "chat_messages" USING BTREE (role);


ALTER TABLE ONLY "chat_messages"
    DROP CONSTRAINT IF EXISTS chat_messages_chat_id_fkey;
ALTER TABLE ONLY "chat_messages"
    ADD CONSTRAINT chat_messages_chat_id_fkey FOREIGN KEY (chat_id) REFERENCES "chats"(id) ON DELETE CASCADE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

DROP TABLE IF EXISTS "chat_messages"
DROP TABLE IF EXISTS "chat"