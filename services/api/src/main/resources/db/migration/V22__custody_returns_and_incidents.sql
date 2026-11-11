-- Frascos cerrados declarados por el custodio; no infiere consumo clinico.
CREATE TABLE app.inventory_custody_events (
    id UUID PRIMARY KEY,
    institution_id UUID NOT NULL REFERENCES app.institutions(id),
    lot_id UUID NOT NULL,
    assignment_id UUID NOT NULL,
    vial_count INTEGER NOT NULL CHECK (vial_count > 0),
    status TEXT NOT NULL CHECK (status IN
      ('RETURN_PENDING', 'RETURN_AVAILABLE', 'RETURN_QUARANTINED', 'INCIDENT_LOST', 'INCIDENT_QUARANTINED')),
    reported_by UUID NOT NULL REFERENCES app.users(id),
    reported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    report_note TEXT NOT NULL CHECK (length(btrim(report_note)) BETWEEN 1 AND 1000),
    confirmed_by UUID REFERENCES app.users(id),
    confirmed_at TIMESTAMPTZ,
    confirmation_note TEXT,
    CONSTRAINT fk_custody_event_assignment FOREIGN KEY (institution_id, lot_id, assignment_id)
      REFERENCES app.inventory_assignments(institution_id, lot_id, id),
    CONSTRAINT ck_custody_event_confirmation CHECK (
      (status IN ('RETURN_PENDING','INCIDENT_LOST','INCIDENT_QUARANTINED')
        AND confirmed_by IS NULL AND confirmed_at IS NULL AND confirmation_note IS NULL)
      OR (status IN ('RETURN_AVAILABLE','RETURN_QUARANTINED')
        AND confirmed_by IS NOT NULL AND confirmed_at IS NOT NULL
        AND confirmation_note IS NOT NULL AND length(btrim(confirmation_note)) BETWEEN 1 AND 1000))
);
CREATE INDEX idx_custody_events_assignment ON app.inventory_custody_events(institution_id, assignment_id);

ALTER TABLE app.inventory_movements DROP CONSTRAINT inventory_movements_kind_check;
ALTER TABLE app.inventory_movements ADD CONSTRAINT ck_inventory_movement_kind
  CHECK (kind IN ('ENTRY', 'DISPATCH', 'RETURN'));
ALTER TABLE app.inventory_movements DROP CONSTRAINT ck_inventory_movement_assignment;
ALTER TABLE app.inventory_movements ADD CONSTRAINT ck_inventory_movement_assignment CHECK (
  (kind = 'ENTRY' AND assignment_id IS NULL) OR
  (kind IN ('DISPATCH', 'RETURN') AND assignment_id IS NOT NULL));
