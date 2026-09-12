-- ============================================================
-- V13__patient_affiliation_and_conditions.sql
-- Fase 2 - seguridad social y condiciones especiales del paciente.
--
--   * patient_affiliation: regimen de afiliacion + aseguradora (EPS).
--   * patient_special_conditions: desplazado, discapacitado, fallecido,
--     victima del conflicto, estudia actualmente.
--   * patient_user_condition: condicion de la usuaria y datos
--     obstetricos/natales.
--
-- 1:1 con el paciente. Idempotente.
-- ============================================================

CREATE TABLE IF NOT EXISTS app.patient_affiliation (
    patient_id         UUID PRIMARY KEY,
    affiliation_regime TEXT,
    insurer            TEXT,
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_patient_affiliation_patient FOREIGN KEY (patient_id)
        REFERENCES app.patients (id) ON DELETE CASCADE,
    CONSTRAINT ck_patient_affiliation_regime CHECK (
        affiliation_regime IS NULL OR affiliation_regime IN (
            'CONTRIBUTIVO', 'SUBSIDIADO', 'POBLACION_POBRE_NO_ASEGURADA',
            'ESPECIAL', 'EXCEPCION', 'NO_ASEGURADO'))
);

CREATE TABLE IF NOT EXISTS app.patient_special_conditions (
    patient_id            UUID PRIMARY KEY,
    displaced             BOOLEAN NOT NULL DEFAULT false,
    disabled              BOOLEAN NOT NULL DEFAULT false,
    deceased              BOOLEAN NOT NULL DEFAULT false,
    armed_conflict_victim BOOLEAN NOT NULL DEFAULT false,
    currently_studying    BOOLEAN,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_patient_special_conditions_patient FOREIGN KEY (patient_id)
        REFERENCES app.patients (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS app.patient_user_condition (
    patient_id             UUID PRIMARY KEY,
    user_condition         TEXT,
    last_menstrual_date    DATE,
    gestation_weeks        INTEGER,
    probable_delivery_date DATE,
    previous_pregnancies   INTEGER,
    has_given_birth        BOOLEAN,
    birth_place_delivery   TEXT,
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_patient_user_condition_patient FOREIGN KEY (patient_id)
        REFERENCES app.patients (id) ON DELETE CASCADE,
    CONSTRAINT ck_patient_user_condition CHECK (
        user_condition IS NULL OR user_condition IN (
            'MUJER_EDAD_FERTIL', 'GESTANTE', 'MUJER_MAYOR_50', 'NO_APLICA'))
);
