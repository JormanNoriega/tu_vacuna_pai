-- Vinculo auditado; no mueve reservas ni cierra el caso.
CREATE TABLE app.inventory_installation_recovery_replacements (
  case_id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  old_installation_id UUID NOT NULL,
  replacement_installation_id UUID NOT NULL,
  vaccinator_id UUID NOT NULL,
  linked_by UUID NOT NULL REFERENCES app.users(id),
  note TEXT NOT NULL CHECK (length(btrim(note)) BETWEEN 1 AND 1000),
  linked_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  CHECK (old_installation_id <> replacement_installation_id),
  FOREIGN KEY (institution_id, case_id, old_installation_id)
    REFERENCES app.inventory_installation_recovery_cases(institution_id, id, installation_id),
  FOREIGN KEY (institution_id, replacement_installation_id, vaccinator_id)
    REFERENCES app.inventory_installations(institution_id, id, vaccinator_id)
);
