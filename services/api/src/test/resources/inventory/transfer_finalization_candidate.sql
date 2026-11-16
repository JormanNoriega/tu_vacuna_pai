-- Prototipo de prueba: no es una migracion ni modifica entregas o custodia.
CREATE TABLE app.transfer_finalizations_candidate (
  id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  assignment_id UUID NOT NULL UNIQUE,
  lot_id UUID NOT NULL,
  kind VARCHAR(20) NOT NULL,
  recorded_by UUID NOT NULL REFERENCES app.users(id),
  evidence TEXT NOT NULL,
  recorded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_test_finalization_assignment FOREIGN KEY (institution_id, lot_id, assignment_id)
    REFERENCES app.inventory_assignments(institution_id, lot_id, id),
  CONSTRAINT ck_test_finalization_evidence CHECK (
    (kind = 'AUTOMATIC' AND evidence = '') OR
    (kind = 'ADMIN_REVIEW' AND length(trim(evidence)) BETWEEN 1 AND 1000))
);
