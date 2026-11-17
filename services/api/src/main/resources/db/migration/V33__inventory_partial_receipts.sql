-- Aditiva: conserva entregas previas y no infiere recepciones parciales historicas.
ALTER TABLE app.inventory_assignments ADD COLUMN received_vials INTEGER NOT NULL DEFAULT 0;
UPDATE app.inventory_assignments SET received_vials = vial_count WHERE status = 'RECEIVED';
ALTER TABLE app.inventory_assignments ADD CONSTRAINT ck_assignment_received_vials
  CHECK (received_vials >= 0 AND received_vials <= vial_count);
ALTER TABLE app.inventory_assignments DROP CONSTRAINT inventory_assignments_status_check;
ALTER TABLE app.inventory_assignments ADD CONSTRAINT inventory_assignments_status_check
  CHECK (status IN ('IN_TRANSIT', 'PARTIALLY_RECEIVED', 'RECEIVED'));

CREATE TABLE app.inventory_receipts (
  id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  assignment_id UUID NOT NULL,
  lot_id UUID NOT NULL,
  received_by UUID NOT NULL REFERENCES app.users(id),
  vials INTEGER NOT NULL CHECK (vials >= 0),
  difference_note TEXT NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_receipt_assignment_scope FOREIGN KEY (institution_id, lot_id, assignment_id)
    REFERENCES app.inventory_assignments(institution_id, lot_id, id)
);
CREATE INDEX idx_inventory_receipts_assignment ON app.inventory_receipts(institution_id, assignment_id);
