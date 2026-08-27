CREATE TABLE app.vaccines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT NOT NULL, code TEXT NOT NULL,
    category TEXT NOT NULL, max_doses SMALLINT NOT NULL, min_age_months INTEGER,
    max_age_months INTEGER, has_laboratory BOOLEAN NOT NULL DEFAULT false,
    has_lot BOOLEAN NOT NULL DEFAULT false, has_syringe BOOLEAN NOT NULL DEFAULT false,
    has_syringe_lot BOOLEAN NOT NULL DEFAULT false, has_diluent BOOLEAN NOT NULL DEFAULT false,
    has_dropper BOOLEAN NOT NULL DEFAULT false, has_pneumococcal_type BOOLEAN NOT NULL DEFAULT false,
    has_vial_count BOOLEAN NOT NULL DEFAULT false, has_observation BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true, version BIGINT NOT NULL DEFAULT 0,
    created_by UUID NOT NULL, updated_by UUID NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), CONSTRAINT uq_vaccines_code UNIQUE (code),
    CONSTRAINT ck_vaccines_doses CHECK (max_doses > 0),
    CONSTRAINT ck_vaccines_age CHECK (min_age_months IS NULL OR max_age_months IS NULL OR max_age_months >= min_age_months)
);

CREATE TABLE app.vaccine_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), vaccine_id UUID NOT NULL REFERENCES app.vaccines(id),
    field_type TEXT NOT NULL, value TEXT NOT NULL,
    value_normalized TEXT GENERATED ALWAYS AS (lower(btrim(value))) STORED,
    display_name TEXT NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0,
    is_default BOOLEAN NOT NULL DEFAULT false, is_active BOOLEAN NOT NULL DEFAULT true,
    version BIGINT NOT NULL DEFAULT 0, created_by UUID NOT NULL, updated_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_vaccine_options_field CHECK (field_type IN ('dose', 'pneumococcalType')),
    CONSTRAINT ck_vaccine_options_value CHECK (length(btrim(value)) > 0)
);
CREATE UNIQUE INDEX uq_vaccine_option_value ON app.vaccine_options(vaccine_id, field_type, value_normalized) WHERE is_active;
CREATE UNIQUE INDEX uq_vaccine_option_default ON app.vaccine_options(vaccine_id, field_type) WHERE is_active AND is_default;
CREATE INDEX idx_vaccine_options_vaccine ON app.vaccine_options(vaccine_id);

CREATE TABLE app.vaccine_option_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), vaccine_id UUID NOT NULL REFERENCES app.vaccines(id),
    field_type TEXT NOT NULL, value TEXT NOT NULL,
    value_normalized TEXT GENERATED ALWAYS AS (lower(btrim(value))) STORED,
    display_name TEXT NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0,
    is_default BOOLEAN NOT NULL DEFAULT false, is_active BOOLEAN NOT NULL DEFAULT true,
    version BIGINT NOT NULL DEFAULT 0,
    created_by UUID NOT NULL, updated_by UUID NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_vaccine_templates_field CHECK (field_type IN ('laboratory', 'syringe', 'dropper', 'observation')),
    CONSTRAINT ck_vaccine_templates_value CHECK (length(btrim(value)) > 0)
);
CREATE UNIQUE INDEX uq_vaccine_option_template_value ON app.vaccine_option_templates(vaccine_id, field_type, value_normalized) WHERE is_active;
CREATE UNIQUE INDEX uq_vaccine_option_template_default ON app.vaccine_option_templates(vaccine_id, field_type) WHERE is_active AND is_default;

CREATE TABLE app.institution_vaccines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), institution_id UUID NOT NULL REFERENCES app.institutions(id),
    vaccine_id UUID NOT NULL REFERENCES app.vaccines(id), is_enabled BOOLEAN NOT NULL DEFAULT true,
    enabled_at TIMESTAMPTZ, enabled_by UUID, version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_institution_vaccines UNIQUE (institution_id, vaccine_id)
);
CREATE INDEX idx_institution_vaccines_institution ON app.institution_vaccines(institution_id);

CREATE TABLE app.institution_vaccine_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), institution_id UUID NOT NULL REFERENCES app.institutions(id),
    vaccine_id UUID NOT NULL REFERENCES app.vaccines(id), field_type TEXT NOT NULL, value TEXT NOT NULL,
    value_normalized TEXT GENERATED ALWAYS AS (lower(btrim(value))) STORED, display_name TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0, is_default BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true, source_template_id UUID REFERENCES app.vaccine_option_templates(id) ON DELETE SET NULL,
    version BIGINT NOT NULL DEFAULT 0, created_by UUID, updated_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_institution_vaccine_options_field CHECK (field_type IN ('laboratory', 'syringe', 'dropper', 'observation')),
    CONSTRAINT ck_institution_vaccine_options_value CHECK (length(btrim(value)) > 0)
);
CREATE UNIQUE INDEX uq_institution_vaccine_option_value ON app.institution_vaccine_options(institution_id, vaccine_id, field_type, value_normalized) WHERE is_active;
CREATE UNIQUE INDEX uq_institution_vaccine_option_default ON app.institution_vaccine_options(institution_id, vaccine_id, field_type) WHERE is_active AND is_default;
CREATE INDEX idx_institution_vaccine_options_context ON app.institution_vaccine_options(institution_id, vaccine_id);

-- Preserve existing installations and rows while introducing the approved names.
INSERT INTO app.permissions(code, name) VALUES
 ('CATALOG_GLOBAL_READ', 'Leer catalogo global'), ('CATALOG_GLOBAL_WRITE', 'Gestionar catalogo global'),
 ('CATALOG_CONFIG_READ', 'Leer configuracion de catalogo'), ('CATALOG_CONFIG_WRITE', 'Gestionar configuracion de catalogo')
ON CONFLICT (code) DO NOTHING;
INSERT INTO app.role_permissions(role_id, permission_id)
SELECT r.id, p.id FROM app.roles r CROSS JOIN app.permissions p
WHERE (r.code = 'SUPER_ADMIN') OR (r.code = 'ADMIN_INSTITUTION' AND p.code IN ('CATALOG_GLOBAL_READ','CATALOG_CONFIG_READ','CATALOG_CONFIG_WRITE'))
   OR (r.code = 'VACCINATOR' AND p.code IN ('CATALOG_GLOBAL_READ','CATALOG_CONFIG_READ'))
   OR (r.code = 'READ_ONLY' AND p.code IN ('CATALOG_GLOBAL_READ','CATALOG_CONFIG_READ'))
ON CONFLICT DO NOTHING;
-- Existing custom roles keep their legacy access semantics as well as the new
-- split permissions; the old permissions remain for old clients.
INSERT INTO app.role_permissions(role_id, permission_id)
SELECT rp.role_id, replacement.id
FROM app.role_permissions rp
JOIN app.permissions legacy ON legacy.id = rp.permission_id
JOIN app.permissions replacement ON replacement.code = CASE legacy.code
    WHEN 'CATALOG_READ' THEN 'CATALOG_GLOBAL_READ'
    WHEN 'CATALOG_WRITE' THEN 'CATALOG_GLOBAL_WRITE' END
WHERE legacy.code IN ('CATALOG_READ', 'CATALOG_WRITE')
ON CONFLICT DO NOTHING;
