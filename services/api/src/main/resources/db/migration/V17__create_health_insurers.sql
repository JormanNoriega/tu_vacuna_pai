-- ============================================================
-- V17__create_health_insurers.sql
-- Catalogo de aseguradoras en salud (EPS). Reemplaza el catalogo de
-- referencia `insurer` (creado vacio en V16) por una tabla dedicada con
-- regimen, codigo, codigo de movilidad y NIT.
--
--   * app.health_insurers: catalogo global (no por institucion). Soft delete
--     con is_active: nunca se borra una fila para conservar historico.
--   * patient_affiliation.insurer_code / patient_guardians.insurer_code:
--     snapshot del NIT elegido (texto, sin FK). El nombre se conserva en
--     `insurer`; esto mantiene la fidelidad historica si la EPS cambia de
--     razon social o NIT.
--
-- El seed del catalogo NO vive en esta migracion: lo aplica
-- HealthInsurerImporter desde resources/catalog/health_insurers.json
-- (idempotente y no destructivo, mismo patron que GeoCatalogImporter para
-- DIVIPOLA). Esta migracion solo define el esquema y las columnas snapshot.
-- ============================================================

CREATE TABLE IF NOT EXISTS app.health_insurers (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nit           TEXT NOT NULL,
    name          TEXT NOT NULL,
    code          TEXT,
    mobility_code TEXT,
    regime        TEXT NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT true,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_health_insurers_nit UNIQUE (nit),
    CONSTRAINT ck_health_insurers_regime CHECK (
        regime IN ('CONTRIBUTIVO', 'SUBSIDIADO', 'AMBOS')
    )
);

CREATE INDEX IF NOT EXISTS idx_health_insurers_active
    ON app.health_insurers (is_active, regime);

-- El seed de las 28 EPS se aplica en el arranque con HealthInsurerImporter
-- (resources/catalog/health_insurers.json). No se inserta aqui para tener una
-- unica fuente de verdad, igual que DIVIPOLA (V10 + GeoCatalogImporter).

-- ---------- Snapshot del NIT en la afiliacion del paciente/acompanante ----------
ALTER TABLE app.patient_affiliation
    ADD COLUMN IF NOT EXISTS insurer_code TEXT;

ALTER TABLE app.patient_guardians
    ADD COLUMN IF NOT EXISTS insurer_code TEXT;

-- ---------- Retirar el catalogo de referencia `insurer` (obsoleto) ----------
DELETE FROM app.reference_catalogs WHERE code = 'insurer';
