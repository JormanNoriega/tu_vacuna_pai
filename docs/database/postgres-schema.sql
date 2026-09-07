-- ============================================================================
-- Tu Vacuna PAI — Esquema PostgreSQL (modelo servidor)
-- Fase 0 · Documento de diseño · Autoridad: Spring Boot (schema `app`)
-- ============================================================================
-- Este documento es el DISEÑO objetivo del modelo servidor clínico + sync.
-- No es una migración ejecutable: las migraciones Flyway reales se crean en
-- Fase 1 (V8+). Sigue las convenciones de V1..V7 (schema `app`, UUID, snake_case).
--
-- Convenciones del proyecto:
--   * Todo vive en schema `app` (Spring es la única puerta; RLS es defensa, ADR-002).
--   * `id UUID PK DEFAULT gen_random_uuid()`.
--   * `created_at/updated_at TIMESTAMPTZ DEFAULT now()`.
--   * Checks e índices parciales para unicidad condicional.
--   * `created_by/updated_by UUID` referenciando app.users(id) (mirror de auth.users).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PACIENTES
-- ----------------------------------------------------------------------------
CREATE TABLE app.patients (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id     UUID NOT NULL REFERENCES app.institutions(id),
    document_type      TEXT NOT NULL,
    document_number    TEXT NOT NULL,
    document_normalized TEXT GENERATED ALWAYS AS (lower(btrim(document_number))) STORED,
    first_name         TEXT NOT NULL,
    last_name          TEXT NOT NULL,
    birth_date         DATE,
    gender             TEXT,
    phone              TEXT,
    email              TEXT,
    address_line       TEXT,
    address_city       TEXT,
    address_department TEXT,
    address_municipality TEXT,
    health_insurer_id  UUID REFERENCES app.health_insurers(id),
    status             TEXT NOT NULL DEFAULT 'ACTIVE',
    version            BIGINT NOT NULL DEFAULT 0,
    created_by         UUID REFERENCES app.users(id),
    updated_by         UUID REFERENCES app.users(id),
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_patients_document_type CHECK (length(btrim(document_type)) > 0),
    CONSTRAINT ck_patients_document_number CHECK (length(btrim(document_number)) > 0),
    CONSTRAINT ck_patients_status CHECK (status IN ('ACTIVE', 'MERGED', 'INACTIVE'))
);

-- Unicidad de identidad dentro del alcance: mismo documento en la misma institución.
CREATE UNIQUE INDEX uq_patients_document_scope
    ON app.patients(institution_id, document_type, document_normalized)
    WHERE status <> 'MERGED';

CREATE INDEX idx_patients_institution ON app.patients(institution_id);
CREATE INDEX idx_patients_document ON app.patients(document_type, document_normalized);

-- ----------------------------------------------------------------------------
-- TUTORES / RESPONSABLES (0..2 por paciente)
-- ----------------------------------------------------------------------------
CREATE TABLE app.patient_guardians (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id   UUID NOT NULL REFERENCES app.patients(id) ON DELETE CASCADE,
    full_name    TEXT NOT NULL,
    relationship TEXT NOT NULL,
    phone        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_patient_guardians_patient ON app.patient_guardians(patient_id);

-- ----------------------------------------------------------------------------
-- HISTORIAL MÉDICO (N por paciente, opcional)
-- ----------------------------------------------------------------------------
CREATE TABLE app.medical_histories (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id   UUID NOT NULL REFERENCES app.patients(id) ON DELETE CASCADE,
    condition    TEXT NOT NULL,
    notes        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_medical_histories_patient ON app.medical_histories(patient_id);

-- ----------------------------------------------------------------------------
-- ASEGURADORAS DE SALUD (catálogo auxiliar)
-- ----------------------------------------------------------------------------
CREATE TABLE app.health_insurers (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code         TEXT NOT NULL,
    name         TEXT NOT NULL,
    is_active    BOOLEAN NOT NULL DEFAULT true,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_health_insurers_code UNIQUE (code)
);

-- ----------------------------------------------------------------------------
-- ATENCIONES
-- ----------------------------------------------------------------------------
-- Estados: DRAFT -> IN_PROGRESS -> COMPLETED | CANCELLED (invariants.md)
CREATE TABLE app.attentions (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id UUID NOT NULL REFERENCES app.institutions(id),
    patient_id     UUID NOT NULL REFERENCES app.patients(id),
    vaccinator_id  UUID REFERENCES app.users(id),          -- quién atiende
    status         TEXT NOT NULL DEFAULT 'DRAFT',
    started_at     TIMESTAMPTZ,
    completed_at   TIMESTAMPTZ,
    cancelled_at   TIMESTAMPTZ,
    cancel_reason  TEXT,
    version        BIGINT NOT NULL DEFAULT 0,
    created_by     UUID REFERENCES app.users(id),
    updated_by     UUID REFERENCES app.users(id),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_attentions_status CHECK (status IN ('DRAFT', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT ck_attentions_cancel CHECK (
        (status = 'CANCELLED' AND cancel_reason IS NOT NULL AND cancelled_at IS NOT NULL)
        OR status <> 'CANCELLED'
    )
);
CREATE INDEX idx_attentions_patient ON app.attentions(patient_id);
CREATE INDEX idx_attentions_institution ON app.attentions(institution_id);
CREATE INDEX idx_attentions_status ON app.attentions(status);

-- ----------------------------------------------------------------------------
-- DOSIS APLICADAS (append-only, D4)
-- ----------------------------------------------------------------------------
-- Estados: REGISTERED -> CANCELLED (invariants.md). Nunca se edita ni borra.
CREATE TABLE app.applied_doses (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attention_id          UUID NOT NULL REFERENCES app.attentions(id),
    institution_vaccine_id UUID REFERENCES app.institution_vaccines(id), -- catálogo efectivo
    vaccine_id            UUID REFERENCES app.vaccines(id),
    status                TEXT NOT NULL DEFAULT 'REGISTERED',
    applied_at            TIMESTAMPTZ NOT NULL,
    administered_by       UUID REFERENCES app.users(id),
    lot                   TEXT,
    -- Snapshot del catálogo en el momento de la aplicación (D7)
    vaccine_name_snapshot TEXT NOT NULL,
    dose_label_snapshot   TEXT,
    catalog_version       BIGINT,
    cancel_reason         TEXT,
    cancelled_at          TIMESTAMPTZ,
    cancelled_by          UUID REFERENCES app.users(id),
    version               BIGINT NOT NULL DEFAULT 0,
    created_by            UUID REFERENCES app.users(id),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_applied_doses_status CHECK (status IN ('REGISTERED', 'CANCELLED')),
    CONSTRAINT ck_applied_doses_cancel CHECK (
        (status = 'CANCELLED' AND cancel_reason IS NOT NULL AND cancelled_at IS NOT NULL)
        OR status <> 'CANCELLED'
    )
);
CREATE INDEX idx_applied_doses_attention ON app.applied_doses(attention_id);
CREATE INDEX idx_applied_doses_vaccine ON app.applied_doses(vaccine_id);

-- ----------------------------------------------------------------------------
-- IDEMPOTENCIA Y CURSOR DE SYNC (D3)
-- ----------------------------------------------------------------------------
-- Nota: la cola de operaciones pendientes (outbox) vive SOLO en el cliente.
-- El servidor registra aquí únicamente operaciones TERMINADAS CON ÉXITO.
-- No existe un estado "en progreso" persistente en el servidor.
CREATE TABLE app.processed_operations (
    operation_id     UUID PRIMARY KEY,
    command_type     TEXT NOT NULL,
    aggregate_id     UUID NOT NULL,
    response_payload JSONB NOT NULL,
    sync_sequence    BIGSERIAL NOT NULL,          -- cursor monotónico del pull
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_processed_operations_sequence ON app.processed_operations(sync_sequence);
CREATE INDEX idx_processed_operations_created ON app.processed_operations(created_at);

-- ----------------------------------------------------------------------------
-- SOLICITUDES DE FUSIÓN DE PACIENTES (D6) — resueltas por ADMIN_INSTITUTION
-- ----------------------------------------------------------------------------
CREATE TABLE app.patient_merge_requests (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id UUID NOT NULL REFERENCES app.institutions(id),
    source_patient_id UUID NOT NULL REFERENCES app.patients(id),
    target_patient_id UUID NOT NULL REFERENCES app.patients(id),
    status         TEXT NOT NULL DEFAULT 'PENDING',
    reason         TEXT,
    created_by     UUID REFERENCES app.users(id),
    resolved_by    UUID REFERENCES app.users(id),
    resolved_at    TIMESTAMPTZ,
    resolution_note TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_patient_merge_requests_status CHECK (
        status IN ('PENDING', 'APPROVED', 'REJECTED')
    ),
    CONSTRAINT uq_patient_merge_pair UNIQUE (source_patient_id, target_patient_id)
);
CREATE INDEX idx_patient_merge_requests_institution ON app.patient_merge_requests(institution_id);
CREATE INDEX idx_patient_merge_requests_status ON app.patient_merge_requests(status);

-- ============================================================================
-- Notas de diseño
-- ============================================================================
-- * sync_scopes ya existe en V1 (app.sync_scopes) y se reutiliza para el scope.
-- * applied_doses guarda snapshot del catálogo para trazabilidad histórica (D7).
-- * version (optimistic locking) en patients y attentions (D5).
-- * Permisos nuevos (PATIENT_*, ATTENTION_*, etc.) ya existen en V1.
-- * No hay tablas sync_operations en el servidor: la cola es exclusiva del cliente.
