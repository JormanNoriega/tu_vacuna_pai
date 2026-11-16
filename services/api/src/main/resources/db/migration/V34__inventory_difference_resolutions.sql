-- La diferencia se resuelve sin presumir que los frascos regresaron al deposito.
ALTER TABLE app.inventory_assignments ADD COLUMN resolved_vials INTEGER NOT NULL DEFAULT 0;
-- V33 aplicada no creo esta restriccion; IF EXISTS permite entornos que si la tuvieran.
ALTER TABLE app.inventory_assignments DROP CONSTRAINT IF EXISTS ck_assignment_receipt_status;
ALTER TABLE app.inventory_assignments DROP CONSTRAINT inventory_assignments_status_check;
ALTER TABLE app.inventory_assignments ADD CONSTRAINT inventory_assignments_status_check
  CHECK (status IN ('IN_TRANSIT', 'PARTIALLY_RECEIVED', 'RECEIVED', 'CLOSED_WITH_DIFFERENCE'));
ALTER TABLE app.inventory_assignments ADD CONSTRAINT ck_assignment_receipt_status
  CHECK (resolved_vials >= 0 AND received_vials + resolved_vials <= vial_count AND (
    (status = 'IN_TRANSIT' AND received_vials = 0 AND resolved_vials = 0)
    OR (status = 'PARTIALLY_RECEIVED' AND received_vials + resolved_vials < vial_count)
    OR (status = 'RECEIVED' AND received_vials = vial_count AND resolved_vials = 0)
    OR (status = 'CLOSED_WITH_DIFFERENCE' AND resolved_vials > 0
        AND received_vials + resolved_vials = vial_count)));

CREATE TABLE app.inventory_difference_resolutions (
  id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  assignment_id UUID NOT NULL,
  lot_id UUID NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('LOST', 'DISPATCH_CORRECTION')),
  vial_count INTEGER NOT NULL CHECK (vial_count > 0),
  note TEXT NOT NULL CHECK (length(btrim(note)) BETWEEN 1 AND 1000),
  recorded_by UUID NOT NULL REFERENCES app.users(id),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_difference_resolution_assignment FOREIGN KEY (institution_id, lot_id, assignment_id)
    REFERENCES app.inventory_assignments(institution_id, lot_id, id)
);
CREATE INDEX idx_difference_resolutions_assignment
  ON app.inventory_difference_resolutions(institution_id, assignment_id);
