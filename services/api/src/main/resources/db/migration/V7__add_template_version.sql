ALTER TABLE app.vaccine_option_templates
    ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 0;
