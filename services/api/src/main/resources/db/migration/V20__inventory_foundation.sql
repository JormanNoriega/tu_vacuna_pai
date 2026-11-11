-- Base aditiva: saldos de frascos cerrados y entregas. No modifica atenciones.
-- El stock inicial se registra expresamente mediante entradas, nunca por lotes clinicos historicos.
CREATE TABLE app.inventory_lots (
    id UUID PRIMARY KEY,
    institution_id UUID NOT NULL REFERENCES app.institutions(id),
    vaccine_id UUID NOT NULL REFERENCES app.vaccines(id),
    manufacturer TEXT NOT NULL CHECK (length(btrim(manufacturer)) > 0),
    lot_number TEXT NOT NULL CHECK (length(btrim(lot_number)) > 0),
    expires_on DATE NOT NULL,
    doses_per_vial INTEGER NOT NULL CHECK (doses_per_vial > 0),
    available_vials INTEGER NOT NULL DEFAULT 0 CHECK (available_vials >= 0),
    created_by UUID NOT NULL REFERENCES app.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_inventory_lot_scope UNIQUE (institution_id, id)
);
CREATE UNIQUE INDEX uq_inventory_lot_identity ON app.inventory_lots
    (institution_id, vaccine_id, lower(btrim(manufacturer)), lower(btrim(lot_number)));

CREATE TABLE app.inventory_assignments (
    id UUID PRIMARY KEY,
    institution_id UUID NOT NULL REFERENCES app.institutions(id),
    lot_id UUID NOT NULL,
    vaccinator_id UUID NOT NULL REFERENCES app.users(id),
    vial_count INTEGER NOT NULL CHECK (vial_count > 0),
    status TEXT NOT NULL CHECK (status IN ('IN_TRANSIT', 'RECEIVED')),
    dispatched_by UUID NOT NULL REFERENCES app.users(id),
    dispatched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    received_at TIMESTAMPTZ,
    CONSTRAINT fk_assignment_lot_scope FOREIGN KEY (institution_id, lot_id)
      REFERENCES app.inventory_lots(institution_id, id),
    CONSTRAINT uq_assignment_scope_lot UNIQUE (institution_id, lot_id, id)
);
CREATE INDEX idx_inventory_assignments_scope ON app.inventory_assignments(institution_id, vaccinator_id);

-- El identificador lo proporciona el cliente para impedir registrar dos veces una operacion.
CREATE TABLE app.inventory_movements (
    id UUID PRIMARY KEY,
    institution_id UUID NOT NULL REFERENCES app.institutions(id),
    lot_id UUID NOT NULL,
    assignment_id UUID,
    kind TEXT NOT NULL CHECK (kind IN ('ENTRY', 'DISPATCH')),
    vial_count INTEGER NOT NULL CHECK (vial_count > 0),
    occurred_at TIMESTAMPTZ NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    recorded_by UUID NOT NULL REFERENCES app.users(id),
    note TEXT NOT NULL CHECK (length(btrim(note)) > 0),
    CONSTRAINT fk_movement_lot_scope FOREIGN KEY (institution_id, lot_id)
      REFERENCES app.inventory_lots(institution_id, id),
    CONSTRAINT fk_movement_assignment_scope FOREIGN KEY (institution_id, lot_id, assignment_id)
      REFERENCES app.inventory_assignments(institution_id, lot_id, id),
    CONSTRAINT ck_inventory_movement_assignment CHECK (
      (kind = 'ENTRY' AND assignment_id IS NULL) OR
      (kind = 'DISPATCH' AND assignment_id IS NOT NULL))
);
CREATE INDEX idx_inventory_movements_scope ON app.inventory_movements(institution_id, lot_id);
