-- ============================================================
-- V4__expand_user_profile.sql
-- Perfil ampliado del personal de salud (VACCINATOR / READ_ONLY):
-- documento, telefono, fecha de nacimiento, genero, profesion y
-- registro profesional.
--
-- Reglas:
--   * El documento se persiste en forma CANONICA (sin espacios, puntos
--     ni guiones, en mayusculas). La normalizacion la aplica Spring como
--     autoridad final ANTES de persistir.
--   * Unicidad por (document_type, document_number) solo cuando existe
--     documento (indice parcial): "CC 12.345.678" y "CC 12345678" son la
--     misma persona tras normalizar.
--   * La profesion es un catalogo (app.professions), no texto libre, para
--     habilitar reglas de negocio futuras.
--   * El registro profesional es NULL cuando no aplica (p. ej. auxiliar de
--     enfermeria): depende de la profesion y del tipo de personal.
-- ============================================================

-- ---------- Catalogo de profesiones ----------
CREATE TABLE app.professions (
    id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    CONSTRAINT uq_professions_code UNIQUE (code)
);

INSERT INTO app.professions (code, name) VALUES
    ('MEDICO',            'Medico'),
    ('ENFERMERO',         'Enfermero(a)'),
    ('AUXILIAR_ENFERMERIA', 'Auxiliar de enfermeria'),
    ('ODONTOLOGO',        'Odontologo'),
    ('BACTERIOLOGO',      'Bacteriologo'),
    ('PROMOTOR_SALUD',    'Promotor de salud'),
    ('OTRO',              'Otro');

-- ---------- app.users: perfil ampliado ----------
ALTER TABLE app.users
    ADD COLUMN document_type TEXT,
    ADD COLUMN document_number TEXT,
    ADD COLUMN phone TEXT,
    ADD COLUMN birth_date DATE,
    ADD COLUMN gender TEXT,
    ADD COLUMN profession_code TEXT,
    ADD COLUMN professional_registration_number TEXT,
    ADD COLUMN professional_registration_type TEXT;

ALTER TABLE app.users
    ADD CONSTRAINT ck_user_document_type CHECK (
        document_type IN ('CC', 'TI', 'CE', 'PASAPORTE')),
    ADD CONSTRAINT ck_user_gender CHECK (
        gender IN ('FEMALE', 'MALE', 'OTHER')),
    ADD CONSTRAINT fk_users_profession FOREIGN KEY (profession_code)
        REFERENCES app.professions (code);

CREATE UNIQUE INDEX uq_users_document
    ON app.users (document_type, document_number)
    WHERE document_number IS NOT NULL;

-- ---------- app.provisioning_operations: espejo del perfil ----------
-- Se persisten para que el replay idempotente (operacion COMPLETED) pueda
-- reconstruir el perfil sin consultar app.users.
ALTER TABLE app.provisioning_operations
    ADD COLUMN document_type TEXT,
    ADD COLUMN document_number TEXT,
    ADD COLUMN phone TEXT,
    ADD COLUMN birth_date DATE,
    ADD COLUMN gender TEXT,
    ADD COLUMN profession_code TEXT,
    ADD COLUMN professional_registration_number TEXT,
    ADD COLUMN professional_registration_type TEXT;