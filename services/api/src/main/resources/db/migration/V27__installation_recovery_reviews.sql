-- Observaciones sobre reservas; no alteran cantidades ni autorizan uso.
ALTER TABLE app.inventory_installation_recovery_cases
  ADD CONSTRAINT uq_recovery_case_scope UNIQUE (institution_id, id, installation_id);
ALTER TABLE app.inventory_installation_reservations
  ADD CONSTRAINT uq_reservation_installation_scope UNIQUE (institution_id, id, installation_id);

CREATE TABLE app.inventory_installation_recovery_reviews (
  id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  case_id UUID NOT NULL,
  installation_id UUID NOT NULL,
  reservation_id UUID NOT NULL,
  observed_vials INTEGER NOT NULL CHECK (observed_vials >= 0),
  reserved_vials_at_review INTEGER NOT NULL CHECK (reserved_vials_at_review > 0),
  note TEXT NOT NULL CHECK (length(btrim(note)) BETWEEN 1 AND 1000),
  reviewed_by UUID NOT NULL REFERENCES app.users(id),
  reviewed_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  FOREIGN KEY (institution_id, case_id, installation_id)
    REFERENCES app.inventory_installation_recovery_cases(institution_id, id, installation_id),
  FOREIGN KEY (institution_id, reservation_id, installation_id)
    REFERENCES app.inventory_installation_reservations(institution_id, id, installation_id)
);
CREATE INDEX idx_recovery_reviews_case ON app.inventory_installation_recovery_reviews(institution_id, case_id);
