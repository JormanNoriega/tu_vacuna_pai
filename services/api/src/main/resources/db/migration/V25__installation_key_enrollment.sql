-- Alta experimental: una clave por instalacion, sin reactivacion automatica.
CREATE TABLE app.inventory_installation_keys (
  installation_id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  vaccinator_id UUID NOT NULL,
  public_key BYTEA,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'REVOKED')),
  enrolled_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  revoked_by UUID REFERENCES app.users(id),
  revocation_note TEXT,
  FOREIGN KEY (institution_id, installation_id, vaccinator_id)
    REFERENCES app.inventory_installations(institution_id, id, vaccinator_id),
  CHECK ((status='ACTIVE' AND public_key IS NOT NULL AND enrolled_at IS NOT NULL
          AND revoked_at IS NULL AND revoked_by IS NULL AND revocation_note IS NULL)
      OR (status='REVOKED' AND revoked_at IS NOT NULL AND revoked_by IS NOT NULL
          AND revocation_note IS NOT NULL AND length(btrim(revocation_note)) BETWEEN 1 AND 1000))
);
