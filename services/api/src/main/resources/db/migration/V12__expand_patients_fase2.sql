-- ============================================================
-- V12__expand_patients_fase2.sql
-- Fase 2 - campos de paciente del wizard "Nueva atencion".
--
-- Agrega identidad ampliada, demografia, migracion, residencia y
-- antecedentes medicos que el legacy captura en el Paso 1 y 2.
-- Idempotente (ALTER ... IF NOT EXISTS / DROP CONSTRAINT IF EXISTS).
--
-- Mapeo de valores:
--   * document_type: 13 codigos DANE/salud (CN, RC, TI, CC, AS, MS, CE,
--     PA, CD, SC, PE, PPT, DE).
--   * sex: MALE / FEMALE / INDETERMINATE.
--   * gender: FEMALE / MALE / OTHER / TRANSGENDER / INDETERMINATE.
--   * area: URBANA / RURAL.
--   * phone_kind: LANDLINE (fijo) / CELLPHONE (celular).
-- ============================================================

-- ---------- patients ----------
ALTER TABLE app.patients
    ADD COLUMN IF NOT EXISTS second_name TEXT,
    ADD COLUMN IF NOT EXISTS second_last_name TEXT,
    ADD COLUMN IF NOT EXISTS birth_country_id UUID,
    ADD COLUMN IF NOT EXISTS birth_place TEXT,
    ADD COLUMN IF NOT EXISTS migration_status TEXT,
    ADD COLUMN IF NOT EXISTS gestational_age_at_birth INTEGER,
    ADD COLUMN IF NOT EXISTS vaccination_card_type TEXT,
    ADD COLUMN IF NOT EXISTS authorize_calls BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS authorize_email BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE app.patients DROP CONSTRAINT IF EXISTS ck_patients_document_type;
ALTER TABLE app.patients ADD CONSTRAINT ck_patients_document_type CHECK (
    document_type IN (
        'CN', 'RC', 'TI', 'CC', 'AS', 'MS', 'CE', 'PA',
        'CD', 'SC', 'PE', 'PPT', 'DE'));

ALTER TABLE app.patients DROP CONSTRAINT IF EXISTS ck_patients_sex;
ALTER TABLE app.patients ADD CONSTRAINT ck_patients_sex CHECK (
    sex IN ('MALE', 'FEMALE', 'INDETERMINATE'));

ALTER TABLE app.patients DROP CONSTRAINT IF EXISTS ck_patients_migration_status;
ALTER TABLE app.patients ADD CONSTRAINT ck_patients_migration_status CHECK (
    migration_status IS NULL OR migration_status IN ('REGULAR', 'IRREGULAR'));

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_patients_birth_country'
    ) THEN
        ALTER TABLE app.patients
            ADD CONSTRAINT fk_patients_birth_country
            FOREIGN KEY (birth_country_id) REFERENCES app.geo_countries (id);
    END IF;
END $$;

-- ---------- patient_demographics ----------
ALTER TABLE app.patient_demographics
    ADD COLUMN IF NOT EXISTS sexual_orientation TEXT;

ALTER TABLE app.patient_demographics
    DROP CONSTRAINT IF EXISTS ck_patient_demographics_gender;
ALTER TABLE app.patient_demographics
    ADD CONSTRAINT ck_patient_demographics_gender CHECK (
        gender IS NULL OR gender IN (
            'FEMALE', 'MALE', 'OTHER', 'TRANSGENDER', 'INDETERMINATE'));

-- ---------- patient_addresses ----------
ALTER TABLE app.patient_addresses
    ADD COLUMN IF NOT EXISTS locality TEXT,
    ADD COLUMN IF NOT EXISTS area TEXT;

ALTER TABLE app.patient_addresses DROP CONSTRAINT IF EXISTS ck_patient_addresses_area;
ALTER TABLE app.patient_addresses ADD CONSTRAINT ck_patient_addresses_area CHECK (
    area IS NULL OR area IN ('URBANA', 'RURAL'));

-- ---------- patient_contacts ----------
ALTER TABLE app.patient_contacts
    ADD COLUMN IF NOT EXISTS phone_kind TEXT;

ALTER TABLE app.patient_contacts DROP CONSTRAINT IF EXISTS ck_patient_contacts_phone_kind;
ALTER TABLE app.patient_contacts ADD CONSTRAINT ck_patient_contacts_phone_kind CHECK (
    phone_kind IS NULL OR phone_kind IN ('LANDLINE', 'CELLPHONE'));

-- ---------- patient_medical_histories ----------
ALTER TABLE app.patient_medical_histories
    ADD COLUMN IF NOT EXISTS has_contraindication BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS contraindication_details TEXT,
    ADD COLUMN IF NOT EXISTS has_previous_reaction BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS reaction_details TEXT,
    ADD COLUMN IF NOT EXISTS history_type TEXT,
    ADD COLUMN IF NOT EXISTS special_observations TEXT;

-- ---------- attentions ----------
ALTER TABLE app.attentions
    ADD COLUMN IF NOT EXISTS complete_scheme BOOLEAN NOT NULL DEFAULT false;
