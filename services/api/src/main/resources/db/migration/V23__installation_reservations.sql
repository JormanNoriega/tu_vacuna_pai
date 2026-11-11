-- Registro y reserva experimental. Un UUID NO prueba posesion del dispositivo.
-- No habilita consumo, descarga offline, liberacion ni reasignacion automatica.
CREATE TABLE app.inventory_installations (
    id UUID PRIMARY KEY,
    institution_id UUID NOT NULL REFERENCES app.institutions(id),
    vaccinator_id UUID NOT NULL REFERENCES app.users(id),
    label TEXT NOT NULL CHECK (length(btrim(label)) BETWEEN 1 AND 80),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_installation_scope_owner UNIQUE (institution_id, id, vaccinator_id)
);
CREATE INDEX idx_installation_scope ON app.inventory_installations(institution_id, vaccinator_id);

ALTER TABLE app.inventory_assignments ADD CONSTRAINT uq_assignment_scope_owner
  UNIQUE (institution_id, lot_id, id, vaccinator_id);

CREATE TABLE app.inventory_installation_reservations (
    id UUID PRIMARY KEY,
    institution_id UUID NOT NULL,
    lot_id UUID NOT NULL,
    assignment_id UUID NOT NULL,
    vaccinator_id UUID NOT NULL,
    installation_id UUID NOT NULL,
    vial_count INTEGER NOT NULL CHECK (vial_count > 0),
    created_by UUID NOT NULL REFERENCES app.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_reservation_assignment_owner FOREIGN KEY (institution_id, lot_id, assignment_id, vaccinator_id)
      REFERENCES app.inventory_assignments(institution_id, lot_id, id, vaccinator_id),
    CONSTRAINT fk_reservation_installation_owner FOREIGN KEY (institution_id, installation_id, vaccinator_id)
      REFERENCES app.inventory_installations(institution_id, id, vaccinator_id)
);
CREATE INDEX idx_installation_reservation_assignment
  ON app.inventory_installation_reservations(institution_id, assignment_id);
