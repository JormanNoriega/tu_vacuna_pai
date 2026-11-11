-- Dictamen documental por revision; no modifica inventario ni cierra casos.
ALTER TABLE app.inventory_installation_recovery_reviews
  ADD CONSTRAINT uq_recovery_review_scope UNIQUE (institution_id, case_id, id);
CREATE TABLE app.inventory_recovery_review_decisions (
  id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  case_id UUID NOT NULL,
  review_id UUID NOT NULL,
  disposition TEXT NOT NULL CHECK (disposition IN ('DOCUMENTED', 'NEEDS_INVESTIGATION')),
  rationale TEXT NOT NULL CHECK (length(btrim(rationale)) BETWEEN 1 AND 1000),
  decided_by UUID NOT NULL REFERENCES app.users(id),
  decided_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  FOREIGN KEY (institution_id, case_id, review_id)
    REFERENCES app.inventory_installation_recovery_reviews(institution_id, case_id, id)
);
CREATE INDEX idx_recovery_decisions_review ON app.inventory_recovery_review_decisions(institution_id, case_id, review_id);
