-- Auditoria de lectura; no cambia el evento, la reserva ni el caso.
CREATE TABLE app.inventory_quarantined_event_access_audit (
  id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  installation_id UUID NOT NULL,
  case_id UUID NOT NULL,
  event_id UUID NOT NULL,
  accessed_by UUID NOT NULL REFERENCES app.users(id),
  reason TEXT NOT NULL CHECK (length(btrim(reason)) BETWEEN 1 AND 1000),
  accessed_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  FOREIGN KEY (institution_id, case_id, installation_id)
    REFERENCES app.inventory_installation_recovery_cases(institution_id, id, installation_id),
  FOREIGN KEY (institution_id, installation_id, event_id)
    REFERENCES app.inventory_quarantined_installation_events(institution_id, installation_id, id)
);
CREATE INDEX idx_quarantined_event_access_case ON app.inventory_quarantined_event_access_audit(institution_id, case_id, event_id);
