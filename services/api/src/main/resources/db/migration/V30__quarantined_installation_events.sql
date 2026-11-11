-- Buzon experimental: ninguna fila aplica consumo ni confirma fecha clinica.
CREATE TABLE app.inventory_quarantined_installation_events (
  id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  installation_id UUID NOT NULL,
  vaccinator_id UUID NOT NULL,
  sequence_number BIGINT NOT NULL CHECK (sequence_number > 0),
  payload BYTEA NOT NULL CHECK (octet_length(payload) BETWEEN 1 AND 65536),
  payload_sha256 BYTEA NOT NULL CHECK (octet_length(payload_sha256) = 32),
  signature BYTEA NOT NULL CHECK (octet_length(signature) = 64),
  received_by UUID NOT NULL REFERENCES app.users(id),
  received_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  status TEXT NOT NULL DEFAULT 'QUARANTINED' CHECK (status = 'QUARANTINED'),
  FOREIGN KEY (institution_id, installation_id, vaccinator_id)
    REFERENCES app.inventory_installations(institution_id, id, vaccinator_id),
  UNIQUE (institution_id, installation_id, sequence_number)
);
