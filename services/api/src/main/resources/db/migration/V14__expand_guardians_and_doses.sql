-- ============================================================
-- V14__expand_guardians_and_doses.sql
-- Fase 2 - datos completos de madre/cuidador y campos de dosis.
--
--   * patient_guardians: segundo nombre/apellido, email, fijo/celular,
--     regimen, aseguradora, etnia y desplazamiento. La relacion distingue
--     madre/padre/cuidador.
--   * applied_doses: lote de jeringa, diluyente, cantidad de frascos y
--     observacion personalizada.
--
-- Idempotente.
-- ============================================================

ALTER TABLE app.patient_guardians
    ADD COLUMN IF NOT EXISTS second_name TEXT,
    ADD COLUMN IF NOT EXISTS second_last_name TEXT,
    ADD COLUMN IF NOT EXISTS email TEXT,
    ADD COLUMN IF NOT EXISTS landline TEXT,
    ADD COLUMN IF NOT EXISTS cellphone TEXT,
    ADD COLUMN IF NOT EXISTS affiliation_regime TEXT,
    ADD COLUMN IF NOT EXISTS insurer TEXT,
    ADD COLUMN IF NOT EXISTS ethnicity TEXT,
    ADD COLUMN IF NOT EXISTS displaced BOOLEAN;

ALTER TABLE app.patient_guardians DROP CONSTRAINT IF EXISTS ck_patient_guardians_relationship;
ALTER TABLE app.patient_guardians ADD CONSTRAINT ck_patient_guardians_relationship CHECK (
    relationship IN ('MOTHER', 'FATHER', 'CAREGIVER', 'OTHER'));

ALTER TABLE app.applied_doses
    ADD COLUMN IF NOT EXISTS syringe_lot TEXT,
    ADD COLUMN IF NOT EXISTS diluent TEXT,
    ADD COLUMN IF NOT EXISTS vial_count INTEGER,
    ADD COLUMN IF NOT EXISTS custom_observation TEXT;
