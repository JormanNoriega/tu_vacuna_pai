-- ============================================================
-- V16__paiweb_and_reference_gaps.sql
-- Ajustes para el wizard "Registrar paciente + vacuna":
--
--   * attentions: marca de ingreso al aplicativo PAIWEB y motivo
--     de no ingreso.
--   * reference_catalogs: catalogo de aseguradoras/EPS (se crea
--     vacio; las opciones se siembran en una migracion posterior).
--   * patient_demographics.gender: alinear el CHECK con los codigos
--     del catalogo de referencia V15 (MASCULINO / FEMENINO /
--     TRANSGENERO / INDETERMINADO), conservando los codigos en
--     ingles por compatibilidad con datos existentes.
--
-- Idempotente (IF NOT EXISTS / DROP CONSTRAINT IF EXISTS).
-- ============================================================

-- ---------- PAIWEB en la atencion ----------
ALTER TABLE app.attentions
    ADD COLUMN IF NOT EXISTS paiweb_registered BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS paiweb_not_registered_reason TEXT;

ALTER TABLE app.attentions
    DROP CONSTRAINT IF EXISTS ck_attentions_paiweb_reason;
ALTER TABLE app.attentions
    ADD CONSTRAINT ck_attentions_paiweb_reason CHECK (
        paiweb_not_registered_reason IS NULL
        OR (paiweb_registered = false
            AND char_length(btrim(paiweb_not_registered_reason)) > 0));

-- ---------- Catalogo de referencia: aseguradora / EPS ----------
INSERT INTO app.reference_catalogs (code, name) VALUES
    ('insurer', 'Aseguradora / EPS')
ON CONFLICT (code) DO UPDATE
    SET name = EXCLUDED.name, updated_at = now();

-- ---------- Genero: alinear con el catalogo de referencia ----------
ALTER TABLE app.patient_demographics
    DROP CONSTRAINT IF EXISTS ck_patient_demographics_gender;
ALTER TABLE app.patient_demographics
    ADD CONSTRAINT ck_patient_demographics_gender CHECK (
        gender IS NULL OR gender IN (
            'MASCULINO', 'FEMENINO', 'TRANSGENERO', 'INDETERMINADO',
            'FEMALE', 'MALE', 'OTHER', 'TRANSGENDER', 'INDETERMINATE'));
