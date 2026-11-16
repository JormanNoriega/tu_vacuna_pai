-- Solo se registran nuevas operaciones. No se infiere el origen de lotes historicos.
CREATE TABLE app.inventory_lot_creation_operations (
  lot_id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('LOT_ONLY', 'LOT_WITH_ENTRY')),
  movement_id UUID UNIQUE REFERENCES app.inventory_movements(id),
  created_by UUID NOT NULL REFERENCES app.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_lot_creation_scope FOREIGN KEY (institution_id, lot_id)
    REFERENCES app.inventory_lots(institution_id, id),
  CONSTRAINT ck_lot_creation_kind CHECK (
    (kind = 'LOT_ONLY' AND movement_id IS NULL) OR
    (kind = 'LOT_WITH_ENTRY' AND movement_id IS NOT NULL))
);
