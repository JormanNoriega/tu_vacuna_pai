-- ============================================================
-- V10__create_geo_catalog.sql
-- Catalogo geografico (DIVIPOLA - DANE, Colombia).
--
--   * geo_countries: paises (seed: Colombia).
--   * geo_departments: departamentos (codigo DANE de 2 digitos).
--   * geo_municipalities: municipios / areas no municipalizadas
--     (codigo DANE, unico a nivel nacional).
--
-- El seed se carga de forma idempotente desde
-- resources/catalog/divipola.json (GeoCatalogImporter), no con
-- miles de INSERT en la migracion.
--
-- Las direcciones de pacientes referencian este catalogo. Las
-- columnas siguen siendo nullable (la direccion es opcional).
-- ============================================================

CREATE TABLE app.geo_countries (
    id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    CONSTRAINT uq_geo_countries_code UNIQUE (code)
);

CREATE TABLE app.geo_departments (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID NOT NULL,
    code       TEXT NOT NULL,
    name       TEXT NOT NULL,
    CONSTRAINT fk_geo_departments_country FOREIGN KEY (country_id)
        REFERENCES app.geo_countries (id),
    CONSTRAINT uq_geo_departments_code UNIQUE (code)
);

CREATE INDEX idx_geo_departments_country ON app.geo_departments (country_id);

CREATE TABLE app.geo_municipalities (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    department_id UUID NOT NULL,
    code          TEXT NOT NULL,
    name          TEXT NOT NULL,
    CONSTRAINT fk_geo_municipalities_department FOREIGN KEY (department_id)
        REFERENCES app.geo_departments (id),
    CONSTRAINT uq_geo_municipalities_code UNIQUE (code)
);

CREATE INDEX idx_geo_municipalities_department
    ON app.geo_municipalities (department_id);

-- Direcciones de pacientes -> catalogo geografico (columnas nullable).
ALTER TABLE app.patient_addresses
    ADD CONSTRAINT fk_patient_addresses_country FOREIGN KEY (country_id)
        REFERENCES app.geo_countries (id),
    ADD CONSTRAINT fk_patient_addresses_department FOREIGN KEY (department_id)
        REFERENCES app.geo_departments (id),
    ADD CONSTRAINT fk_patient_addresses_municipality FOREIGN KEY (municipality_id)
        REFERENCES app.geo_municipalities (id);
