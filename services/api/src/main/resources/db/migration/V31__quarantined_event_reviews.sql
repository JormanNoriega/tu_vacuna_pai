-- Dictamen documental, no libera cuarentena ni modifica inventario.
ALTER TABLE app.inventory_quarantined_installation_events
  ADD CONSTRAINT uq_quarantined_event_scope UNIQUE (institution_id, installation_id, id);
CREATE TABLE app.inventory_quarantined_event_reviews (
  id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  installation_id UUID NOT NULL,
  case_id UUID NOT NULL,
  event_id UUID NOT NULL,
  disposition TEXT NOT NULL CHECK (disposition IN ('DOCUMENTED', 'NEEDS_INVESTIGATION')),
  rationale TEXT NOT NULL CHECK (length(btrim(rationale)) BETWEEN 1 AND 1000),
  reviewed_by UUID NOT NULL REFERENCES app.users(id),
  reviewed_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  FOREIGN KEY (institution_id, case_id, installation_id)
    REFERENCES app.inventory_installation_recovery_cases(institution_id, id, installation_id),
  FOREIGN KEY (institution_id, installation_id, event_id)
    REFERENCES app.inventory_quarantined_installation_events(institution_id, installation_id, id)
);
CREATE INDEX idx_quarantined_event_reviews_case ON app.inventory_quarantined_event_reviews(institution_id, case_id, event_id);
