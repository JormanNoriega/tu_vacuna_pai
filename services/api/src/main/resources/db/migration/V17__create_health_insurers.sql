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
-- Seed idempotente (ON CONFLICT (nit) DO UPDATE). No reactiva filas que se
-- hayan desactivado manualmente (is_active se deja intacto).
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

-- ---------- Seed (28 entidades) ----------
INSERT INTO app.health_insurers (nit, name, code, mobility_code, regime) VALUES
    ('900226715', 'Coosalud EPS-S', 'ESS024 - EPS042', 'ESSC24 - EPSS42', 'AMBOS'),
    ('900156264', 'Nueva EPS', 'EPS037 - EPSS41', 'EPSS37 - EPS041', 'AMBOS'),
    ('806008394', 'Mutual SER', 'ESS207 - EPS048', 'ESSC07 - EPSS48', 'AMBOS'),
    ('900914254', 'Salud Mia', 'EPS046', 'EPSS46', 'AMBOS'),
    ('830113831', 'Aliansalud EPS', 'EPS001', 'EPSS01', 'CONTRIBUTIVO'),
    ('800130907', 'Salud Total EPS S.A.', 'EPS002', 'EPSS02', 'CONTRIBUTIVO'),
    ('800251440', 'EPS Sanitas', 'EPS005', 'EPSS05', 'CONTRIBUTIVO'),
    ('800088702', 'EPS Sura', 'EPS010', 'EPSS10', 'CONTRIBUTIVO'),
    ('830003564', 'Famisanar EPS', 'EPS017', 'EPSS17', 'CONTRIBUTIVO'),
    ('805001157', 'Servicio Occidental de Salud EPS SOS', 'EPS018', 'EPSS18', 'CONTRIBUTIVO'),
    ('890303093', 'Comfenalco Valle', 'EPS012', 'EPSS12', 'CONTRIBUTIVO'),
    ('860066942', 'Compensar EPS', 'EPS008', 'EPSS08', 'CONTRIBUTIVO'),
    ('890904996', 'EPM - Empresas Publicas de Medellin', 'EAS016', 'N/A', 'CONTRIBUTIVO'),
    ('800112806', 'Fondo de Pasivo Social de Ferrocarriles Nacionales de Colombia', 'EAS027', 'N/A', 'CONTRIBUTIVO'),
    ('890102044', 'Cajacopi Atlantico', 'CCF055', 'CCFC55', 'SUBSIDIADO'),
    ('891856000', 'Capresoca', 'EPS025', 'EPSC25', 'SUBSIDIADO'),
    ('891600091', 'Comfachoco', 'CCF102', 'CCFC20', 'SUBSIDIADO'),
    ('890500675', 'Comfaoriente', 'CCF050', 'CCFC50', 'SUBSIDIADO'),
    ('901543761', 'EPS Familiar de Colombia', 'CCF033', 'CCFC33', 'SUBSIDIADO'),
    ('900935126', 'Asmet Salud', 'ESS062', 'ESSC62', 'SUBSIDIADO'),
    ('901021565', 'Emssanar E.S.S.', 'ESS118', 'ESSC18', 'SUBSIDIADO'),
    ('900298372', 'Capital Salud EPS-S', 'EPSS34', 'EPSC34', 'SUBSIDIADO'),
    ('900604350', 'Savia Salud EPS', 'EPSS40', 'EPS040', 'SUBSIDIADO'),
    ('824001398', 'Dusakawi EPSI', 'EPSI01', 'EPSIC1', 'SUBSIDIADO'),
    ('817001773', 'Asociacion Indigena del Cauca EPSI', 'EPSI03', 'EPSIC3', 'SUBSIDIADO'),
    ('839000495', 'Anas Wayuu EPSI', 'EPSI04', 'EPSIC4', 'SUBSIDIADO'),
    ('837000084', 'Mallamas EPSI', 'EPSI05', 'EPSIC5', 'SUBSIDIADO'),
    ('809008362', 'Pijaos Salud EPSI', 'EPSI06', 'EPSIC6', 'SUBSIDIADO')
ON CONFLICT (nit) DO UPDATE
    SET name = EXCLUDED.name,
        code = EXCLUDED.code,
        mobility_code = EXCLUDED.mobility_code,
        regime = EXCLUDED.regime,
        updated_at = now();

-- ---------- Snapshot del NIT en la afiliacion del paciente/acompanante ----------
ALTER TABLE app.patient_affiliation
    ADD COLUMN IF NOT EXISTS insurer_code TEXT;

ALTER TABLE app.patient_guardians
    ADD COLUMN IF NOT EXISTS insurer_code TEXT;

-- ---------- Retirar el catalogo de referencia `insurer` (obsoleto) ----------
DELETE FROM app.reference_catalogs WHERE code = 'insurer';
