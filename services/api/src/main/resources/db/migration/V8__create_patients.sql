-- ============================================================
-- V8__create_patients.sql
-- Modulo clinico - pacientes.
--
-- Crea el agregado Patient con sus tablas hijas (contactos,
-- demografia, direcciones, tutores y antecedentes) y la
-- infraestructura compartida de operaciones clinicas:
--   * processed_operations: idempotencia por operation_id (D3),
--     compartida entre los REST directos y /sync/push.
--   * audit_events: trazabilidad de las operaciones clinicas.
--
-- Reglas:
--   * El paciente pertenece a la institucion que lo crea (scope
--     institucional obligatorio, ADR-007). La institucion nunca se
--     confia al cliente: se deriva del actor en Spring.
--   * La unicidad de documento es por institucion: el mismo documento
--     puede existir en dos redes y se resuelve luego por
--     PatientMergeRequest (V9).
--   * El documento se persiste en forma CANONICA (sin espacios, puntos
--     ni guiones, en mayusculas); la normalizacion la aplica Spring
--     como autoridad final antes de persistir.
-- ============================================================

-- ---------- Patients ----------
CREATE TABLE app.patients (
    id              UUID        PRIMARY KEY,
    institution_id  UUID        NOT NULL,
    document_type   TEXT        NOT NULL,
    document_number TEXT        NOT NULL,
    first_name      TEXT        NOT NULL,
    last_name       TEXT        NOT NULL,
    birth_date      DATE        NOT NULL,
    sex             TEXT        NOT NULL,
    status          TEXT        NOT NULL DEFAULT 'ACTIVE',
    version         BIGINT      NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_patients_institution FOREIGN KEY (institution_id)
        REFERENCES app.institutions (id),
    CONSTRAINT uq_patients_document UNIQUE (
        institution_id, document_type, document_number),
    CONSTRAINT ck_patients_document_type CHECK (
        document_type IN ('CC', 'TI', 'CE', 'PASAPORTE')),
    CONSTRAINT ck_patients_sex CHECK (sex IN ('MALE', 'FEMALE')),
    CONSTRAINT ck_patients_status CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

CREATE INDEX idx_patients_institution ON app.patients (institution_id);
CREATE INDEX idx_patients_document ON app.patients (document_type, document_number);

-- ---------- Patient contacts ----------
CREATE TABLE app.patient_contacts (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID        NOT NULL,
    type       TEXT        NOT NULL,
    value      TEXT        NOT NULL,
    is_primary BOOLEAN     NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_patient_contacts_patient FOREIGN KEY (patient_id)
        REFERENCES app.patients (id) ON DELETE CASCADE,
    CONSTRAINT ck_patient_contacts_type CHECK (type IN ('PHONE', 'EMAIL', 'OTHER'))
);

CREATE INDEX idx_patient_contacts_patient ON app.patient_contacts (patient_id);

-- ---------- Patient demographics (1:1) ----------
CREATE TABLE app.patient_demographics (
    patient_id      UUID        PRIMARY KEY,
    gender          TEXT,
    ethnicity       TEXT,
    education_level TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_patient_demographics_patient FOREIGN KEY (patient_id)
        REFERENCES app.patients (id) ON DELETE CASCADE,
    CONSTRAINT ck_patient_demographics_gender CHECK (
        gender IS NULL OR gender IN ('FEMALE', 'MALE', 'OTHER'))
);

-- ---------- Patient addresses ----------
-- municipality_id/department_id/country_id referenciaran app.geo_* cuando
-- ese catalogo se implemente; por ahora se guardan como UUID sin FK.
CREATE TABLE app.patient_addresses (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id      UUID        NOT NULL,
    street          TEXT,
    municipality_id UUID,
    department_id   UUID,
    country_id      UUID,
    is_primary      BOOLEAN     NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_patient_addresses_patient FOREIGN KEY (patient_id)
        REFERENCES app.patients (id) ON DELETE CASCADE
);

CREATE INDEX idx_patient_addresses_patient ON app.patient_addresses (patient_id);

-- ---------- Patient guardians ----------
CREATE TABLE app.patient_guardians (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id      UUID        NOT NULL,
    relationship    TEXT        NOT NULL,
    full_name       TEXT        NOT NULL,
    document_type   TEXT,
    document_number TEXT,
    phone           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_patient_guardians_patient FOREIGN KEY (patient_id)
        REFERENCES app.patients (id) ON DELETE CASCADE,
    CONSTRAINT ck_patient_guardians_relationship CHECK (
        relationship IN ('MOTHER', 'FATHER', 'CAREGIVER', 'OTHER'))
);

CREATE INDEX idx_patient_guardians_patient ON app.patient_guardians (patient_id);

-- ---------- Patient medical histories ----------
CREATE TABLE app.patient_medical_histories (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id   UUID        NOT NULL,
    condition    TEXT        NOT NULL,
    diagnosed_at DATE,
    notes        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_patient_medical_histories_patient FOREIGN KEY (patient_id)
        REFERENCES app.patients (id) ON DELETE CASCADE
);

CREATE INDEX idx_patient_medical_histories_patient
    ON app.patient_medical_histories (patient_id);

-- ============================================================
-- Idempotencia de comandos clinicos (D3)
--
-- NO confundir con app.provisioning_operations (V3), que es para
-- aprovisionamiento de identidad. Esta tabla registra las operaciones
-- clinicas terminadas con exito y su respuesta original, para que un
-- reenvio con el mismo operation_id devuelva la respuesta original sin
-- reprocesar. Compartida entre los REST directos y /sync/push.
-- ============================================================
CREATE TABLE app.processed_operations (
    operation_id     UUID        PRIMARY KEY,
    command_type     TEXT        NOT NULL,
    aggregate_id     UUID,
    response_payload JSONB       NOT NULL,
    sync_sequence    BIGSERIAL   NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_processed_operations_seq
    ON app.processed_operations (sync_sequence);

-- ============================================================
-- Auditoria de operaciones clinicas
-- ============================================================
CREATE TABLE app.audit_events (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id            UUID        NOT NULL,
    institution_id      UUID        NOT NULL,
    action              TEXT        NOT NULL,
    resource_type       TEXT        NOT NULL,
    resource_id         UUID        NOT NULL,
    client_operation_id UUID,
    payload             JSONB       NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_audit_events_actor FOREIGN KEY (actor_id)
        REFERENCES app.users (id),
    CONSTRAINT fk_audit_events_institution FOREIGN KEY (institution_id)
        REFERENCES app.institutions (id)
);

CREATE INDEX idx_audit_events_actor ON app.audit_events (actor_id);
CREATE INDEX idx_audit_events_resource ON app.audit_events (resource_type, resource_id);
CREATE INDEX idx_audit_events_institution ON app.audit_events (institution_id);
CREATE INDEX idx_audit_events_created ON app.audit_events (created_at);
