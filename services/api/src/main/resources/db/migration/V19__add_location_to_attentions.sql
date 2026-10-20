-- ============================================================
-- V19__add_location_to_attentions.sql
-- Agrega soporte de geolocalizacion (latitud y longitud) a las
-- atenciones de vacunacion.
-- ============================================================

ALTER TABLE app.attentions
    ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- Restricciones de cota geografica valida
ALTER TABLE app.attentions DROP CONSTRAINT IF EXISTS ck_attentions_latitude;
ALTER TABLE app.attentions ADD CONSTRAINT ck_attentions_latitude
    CHECK (latitude IS NULL OR (latitude >= -90.0 AND latitude <= 90.0));

ALTER TABLE app.attentions DROP CONSTRAINT IF EXISTS ck_attentions_longitude;
ALTER TABLE app.attentions ADD CONSTRAINT ck_attentions_longitude
    CHECK (longitude IS NULL OR (longitude >= -180.0 AND longitude <= 180.0));
