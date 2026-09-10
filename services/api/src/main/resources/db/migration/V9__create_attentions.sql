-- ============================================================
-- V9__create_attentions.sql
-- Modulo clinico - atenciones y dosis aplicadas.
--
--   * attentions: agregado raiz de la atencion de vacunacion.
--   * applied_doses: dosis aplicadas, append-only, con snapshot del
--     catalogo vigente al momento del registro.
--   * patient_merge_requests: bandeja de duplicados de paciente
--     (la resolucion por ADMIN_INSTITUTION se implementa despues).
--
-- Reglas:
--   * Attention es el agregado raiz; AppliedDose vive dentro de el y
--     no tiene CRUD independiente.
--   * Attention es mutable solo en DRAFT/IN_PROGRESS. COMPLETED es
--     inmutable y solo puede anularse con motivo.
--   * AppliedDose es append-only: REGISTERED -> CANCELLED(motivo,
--     actor, timestamp). Nunca UPDATE ni DELETE.
--   * La institucion de la atencion se deriva del actor en Spring;
--     nunca se confia al cliente.
-- ============================================================

-- ---------- Attentions ----------
CREATE TABLE app.attentions (
    id                  UUID        PRIMARY KEY,
    patient_id          UUID        NOT NULL,
    professional_id     UUID        NOT NULL,
    institution_id      UUID        NOT NULL,
    attention_date      TIMESTAMPTZ NOT NULL,
    consecutive         BIGINT,
    client_operation_id UUID,
    status              TEXT        NOT NULL DEFAULT 'DRAFT',
    observations        TEXT,
    version             BIGINT      NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_attentions_patient FOREIGN KEY (patient_id)
        REFERENCES app.patients (id),
    CONSTRAINT fk_attentions_professional FOREIGN KEY (professional_id)
        REFERENCES app.users (id),
    CONSTRAINT fk_attentions_institution FOREIGN KEY (institution_id)
        REFERENCES app.institutions (id),
    CONSTRAINT uq_attentions_operation UNIQUE (client_operation_id),
    CONSTRAINT ck_attentions_status CHECK (
        status IN ('DRAFT', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'))
);

CREATE INDEX idx_attentions_patient ON app.attentions (patient_id);
CREATE INDEX idx_attentions_institution ON app.attentions (institution_id);
CREATE INDEX idx_attentions_professional ON app.attentions (professional_id);

-- ---------- Applied doses (append-only) ----------
-- lot_id es nullable y sin FK: referenciara app.inventory_lots cuando el
-- modulo de inventario exista. Mientras tanto se guarda lot_number (texto).
CREATE TABLE app.applied_doses (
    id                          UUID        PRIMARY KEY,
    attention_id                UUID        NOT NULL,
    vaccine_id                  UUID        NOT NULL,
    lot_id                      UUID,
    lot_number                  TEXT,
    application_date            TIMESTAMPTZ NOT NULL,
    dose_option_id              UUID,
    pneumococcal_type_option_id UUID,
    vaccine_name_snapshot       TEXT        NOT NULL,
    vaccine_code_snapshot       TEXT        NOT NULL,
    dose_label_snapshot         TEXT        NOT NULL,
    dose_value_snapshot         TEXT,
    pneumococcal_type_snapshot  TEXT,
    catalog_version             BIGINT      NOT NULL,
    selected_laboratory_id      UUID,
    selected_laboratory_snapshot TEXT,
    selected_syringe_id         UUID,
    selected_syringe_snapshot   TEXT,
    selected_dropper_id         UUID,
    selected_dropper_snapshot   TEXT,
    selected_observation_id     UUID,
    selected_observation_snapshot TEXT,
    status                      TEXT        NOT NULL DEFAULT 'REGISTERED',
    cancelled_reason            TEXT,
    cancelled_by                UUID,
    cancelled_at                TIMESTAMPTZ,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_applied_doses_attention FOREIGN KEY (attention_id)
        REFERENCES app.attentions (id),
    CONSTRAINT fk_applied_doses_vaccine FOREIGN KEY (vaccine_id)
        REFERENCES app.vaccines (id),
    CONSTRAINT fk_applied_doses_dose_option FOREIGN KEY (dose_option_id)
        REFERENCES app.vaccine_options (id),
    CONSTRAINT fk_applied_doses_pneumo_option FOREIGN KEY (pneumococcal_type_option_id)
        REFERENCES app.vaccine_options (id),
    CONSTRAINT fk_applied_doses_laboratory FOREIGN KEY (selected_laboratory_id)
        REFERENCES app.institution_vaccine_options (id),
    CONSTRAINT fk_applied_doses_syringe FOREIGN KEY (selected_syringe_id)
        REFERENCES app.institution_vaccine_options (id),
    CONSTRAINT fk_applied_doses_dropper FOREIGN KEY (selected_dropper_id)
        REFERENCES app.institution_vaccine_options (id),
    CONSTRAINT fk_applied_doses_observation FOREIGN KEY (selected_observation_id)
        REFERENCES app.institution_vaccine_options (id),
    CONSTRAINT fk_applied_doses_cancelled_by FOREIGN KEY (cancelled_by)
        REFERENCES app.users (id),
    CONSTRAINT ck_applied_doses_status CHECK (
        status IN ('REGISTERED', 'CANCELLED')),
    CONSTRAINT ck_applied_doses_cancel CHECK (
        (status = 'REGISTERED' AND cancelled_reason IS NULL AND cancelled_by IS NULL
            AND cancelled_at IS NULL)
        OR (status = 'CANCELLED' AND cancelled_reason IS NOT NULL
            AND cancelled_by IS NOT NULL AND cancelled_at IS NOT NULL))
);

CREATE INDEX idx_applied_doses_attention ON app.applied_doses (attention_id);
CREATE INDEX idx_applied_doses_vaccine ON app.applied_doses (vaccine_id);

-- ---------- Patient merge requests ----------
CREATE TABLE app.patient_merge_requests (
    id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    duplicate_patient_id UUID        NOT NULL,
    canonical_patient_id UUID,
    status               TEXT        NOT NULL DEFAULT 'PENDING_REVIEW',
    resolved_by          UUID,
    resolved_at          TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_merge_duplicate FOREIGN KEY (duplicate_patient_id)
        REFERENCES app.patients (id),
    CONSTRAINT fk_merge_canonical FOREIGN KEY (canonical_patient_id)
        REFERENCES app.patients (id),
    CONSTRAINT fk_merge_resolved_by FOREIGN KEY (resolved_by)
        REFERENCES app.users (id),
    CONSTRAINT ck_merge_status CHECK (
        status IN ('PENDING_REVIEW', 'RESOLVED', 'REJECTED'))
);

CREATE INDEX idx_merge_status ON app.patient_merge_requests (status);
CREATE INDEX idx_merge_duplicate ON app.patient_merge_requests (duplicate_patient_id);
