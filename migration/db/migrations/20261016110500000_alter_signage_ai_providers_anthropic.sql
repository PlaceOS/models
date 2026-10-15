-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

-- Anthropic joins the vendors a provider row can point at; its rows carry an
-- api_key in credentials and a text_model, and cannot generate images.
ALTER TABLE "signage_ai_providers" DROP CONSTRAINT IF EXISTS signage_ai_providers_provider_check;
ALTER TABLE "signage_ai_providers" ADD CONSTRAINT signage_ai_providers_provider_check
  CHECK (provider IN ('OPENAI', 'AZURE_OPENAI', 'GOOGLE_VERTEX', 'ANTHROPIC'));

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "signage_ai_providers" DROP CONSTRAINT IF EXISTS signage_ai_providers_provider_check;
ALTER TABLE "signage_ai_providers" ADD CONSTRAINT signage_ai_providers_provider_check
  CHECK (provider IN ('OPENAI', 'AZURE_OPENAI', 'GOOGLE_VERTEX'));
