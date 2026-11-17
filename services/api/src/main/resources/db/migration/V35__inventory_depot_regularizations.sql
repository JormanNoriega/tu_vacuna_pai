-- La regularizacion acredita permanencia fisica confirmada; no es una devolucion.
ALTER TABLE app.inventory_difference_resolutions
  ADD CONSTRAINT uq_difference_resolution_scope UNIQUE (institution_id, id);
CREATE TABLE app.inventory_depot_regularizations (
  id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  resolution_id UUID NOT NULL,
  vial_count INTEGER NOT NULL CHECK (vial_count > 0),
  note TEXT NOT NULL CHECK (length(btrim(note)) BETWEEN 1 AND 1000),
  recorded_by UUID NOT NULL REFERENCES app.users(id),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_regularization_resolution FOREIGN KEY (institution_id, resolution_id)
    REFERENCES app.inventory_difference_resolutions(institution_id, id),
  CONSTRAINT fk_regularization_movement FOREIGN KEY (id) REFERENCES app.inventory_movements(id)
);
CREATE INDEX idx_depot_regularizations_resolution
  ON app.inventory_depot_regularizations(institution_id, resolution_id);
ALTER TABLE app.inventory_movements DROP CONSTRAINT ck_inventory_movement_kind;
ALTER TABLE app.inventory_movements ADD CONSTRAINT ck_inventory_movement_kind
  CHECK (kind IN ('ENTRY', 'DISPATCH', 'RETURN', 'DEPOT_CORRECTION'));
ALTER TABLE app.inventory_movements DROP CONSTRAINT ck_inventory_movement_assignment;
ALTER TABLE app.inventory_movements ADD CONSTRAINT ck_inventory_movement_assignment CHECK (
  (kind = 'ENTRY' AND assignment_id IS NULL) OR
  (kind IN ('DISPATCH', 'RETURN', 'DEPOT_CORRECTION') AND assignment_id IS NOT NULL));
