-- Align the catalog columns with the current JPA model without rewriting V5.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'vaccines' AND column_name = 'requires_lot'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app' AND table_name = 'vaccines' AND column_name = 'has_lot'
    ) THEN
        ALTER TABLE app.vaccines RENAME COLUMN requires_lot TO has_lot;
    END IF;
END $$;

ALTER TABLE app.vaccines
    ADD COLUMN IF NOT EXISTS has_laboratory BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS has_syringe BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS has_syringe_lot BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS has_diluent BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS has_dropper BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS has_pneumococcal_type BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS has_vial_count BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS has_observation BOOLEAN NOT NULL DEFAULT false;
