-- Prototipo exclusivo de prueba; NO es una migracion Flyway.
-- No crea saldos ni vincula automaticamente datos historicos.
ALTER TABLE app.inventory_assignments ADD CONSTRAINT uq_test_assignment_custodian_scope
  UNIQUE (institution_id, lot_id, vaccinator_id, id);

CREATE TABLE app.individual_custodies_candidate (
  id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  lot_id UUID NOT NULL,
  custodian_id UUID NOT NULL REFERENCES app.users(id),
  created_by UUID NOT NULL REFERENCES app.users(id),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_test_custody_lot FOREIGN KEY (institution_id, lot_id)
    REFERENCES app.inventory_lots(institution_id, id),
  CONSTRAINT uq_test_custody_owner_lot UNIQUE (institution_id, lot_id, custodian_id),
  CONSTRAINT uq_test_custody_scope UNIQUE (institution_id, lot_id, custodian_id, id)
);

-- La entrega es la unidad de procedencia. Sus recepciones y novedades
-- permanecen en sus propias tablas con sus identificadores originales.
CREATE TABLE app.individual_custody_origins_candidate (
  assignment_id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  lot_id UUID NOT NULL,
  custodian_id UUID NOT NULL,
  custody_id UUID NOT NULL,
  linked_by UUID NOT NULL REFERENCES app.users(id),
  linked_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_test_origin_custody FOREIGN KEY (institution_id, lot_id, custodian_id, custody_id)
    REFERENCES app.individual_custodies_candidate(institution_id, lot_id, custodian_id, id),
  CONSTRAINT fk_test_origin_assignment FOREIGN KEY (institution_id, lot_id, custodian_id, assignment_id)
    REFERENCES app.inventory_assignments(institution_id, lot_id, vaccinator_id, id)
);
