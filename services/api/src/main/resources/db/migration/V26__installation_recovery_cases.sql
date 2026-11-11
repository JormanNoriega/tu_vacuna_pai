-- Apertura de conciliacion; no libera ni transfiere reservas.
CREATE TABLE app.inventory_installation_recovery_cases (
  id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  installation_id UUID NOT NULL,
  vaccinator_id UUID NOT NULL,
  opened_by UUID NOT NULL REFERENCES app.users(id),
  reason TEXT NOT NULL CHECK (length(btrim(reason)) BETWEEN 1 AND 1000),
  opened_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status = 'OPEN'),
  FOREIGN KEY (institution_id, installation_id, vaccinator_id)
    REFERENCES app.inventory_installations(institution_id, id, vaccinator_id),
  UNIQUE (institution_id, installation_id)
);
