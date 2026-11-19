-- Aditiva y sin backfill: no reconstruye existencias ni atribuye historia.
CREATE TABLE app.inventory_transfer_finalizations (
  id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  lot_id UUID NOT NULL,
  assignment_id UUID NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('AUTOMATIC', 'ADMIN_REVIEW')),
  recorded_by UUID NOT NULL REFERENCES app.users(id),
  note TEXT NOT NULL CHECK (length(btrim(note)) BETWEEN 1 AND 1000),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (institution_id, assignment_id),
  FOREIGN KEY (institution_id, lot_id, assignment_id)
    REFERENCES app.inventory_assignments(institution_id, lot_id, id)
);
CREATE TABLE app.inventory_custody_counts (
  id UUID PRIMARY KEY,
  sequence BIGINT GENERATED ALWAYS AS IDENTITY,
  institution_id UUID NOT NULL,
  lot_id UUID NOT NULL,
  assignment_id UUID NOT NULL,
  closed_vials INTEGER NOT NULL CHECK (closed_vials >= 0),
  open_vials INTEGER NOT NULL CHECK (open_vials >= 0),
  exhausted_vials INTEGER NOT NULL CHECK (exhausted_vials >= 0),
  discarded_vials INTEGER NOT NULL CHECK (discarded_vials >= 0),
  discarded_doses INTEGER NOT NULL CHECK (discarded_doses >= 0),
  note TEXT NOT NULL CHECK (length(btrim(note)) BETWEEN 1 AND 1000),
  recorded_by UUID NOT NULL REFERENCES app.users(id),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (institution_id, assignment_id, id),
  FOREIGN KEY (institution_id, lot_id, assignment_id)
    REFERENCES app.inventory_assignments(institution_id, lot_id, id)
);
CREATE INDEX idx_custody_counts_assignment
  ON app.inventory_custody_counts(institution_id, assignment_id, sequence DESC);
CREATE TABLE app.inventory_clinical_links (
  id UUID PRIMARY KEY,
  institution_id UUID NOT NULL,
  lot_id UUID NOT NULL,
  assignment_id UUID NOT NULL,
  dose_id UUID NOT NULL UNIQUE REFERENCES app.applied_doses(id),
  note TEXT NOT NULL CHECK (length(btrim(note)) BETWEEN 1 AND 1000),
  recorded_by UUID NOT NULL REFERENCES app.users(id),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (institution_id, lot_id, assignment_id)
    REFERENCES app.inventory_assignments(institution_id, lot_id, id)
);
CREATE INDEX idx_clinical_links_assignment ON app.inventory_clinical_links(institution_id, assignment_id);
CREATE TABLE app.inventory_custody_reviews (
  id UUID PRIMARY KEY,
  sequence BIGINT GENERATED ALWAYS AS IDENTITY,
  institution_id UUID NOT NULL,
  assignment_id UUID NOT NULL,
  count_id UUID NOT NULL,
  basis TEXT NOT NULL,
  note TEXT NOT NULL CHECK (length(btrim(note)) BETWEEN 1 AND 1000),
  recorded_by UUID NOT NULL REFERENCES app.users(id),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (institution_id, assignment_id, count_id)
    REFERENCES app.inventory_custody_counts(institution_id, assignment_id, id)
);
CREATE INDEX idx_custody_reviews_assignment
  ON app.inventory_custody_reviews(institution_id, assignment_id, sequence DESC);
CREATE INDEX idx_transfer_finalizations_actor ON app.inventory_transfer_finalizations(recorded_by);
CREATE INDEX idx_custody_counts_actor ON app.inventory_custody_counts(recorded_by);
CREATE INDEX idx_clinical_links_actor ON app.inventory_clinical_links(recorded_by);
CREATE INDEX idx_custody_reviews_actor ON app.inventory_custody_reviews(recorded_by);
CREATE INDEX idx_custody_reviews_count ON app.inventory_custody_reviews(institution_id, assignment_id, count_id);

-- Solo backend: no publica datos ni escrituras mediante PostgREST.
ALTER TABLE app.inventory_transfer_finalizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.inventory_custody_counts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.inventory_clinical_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.inventory_custody_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON app.inventory_transfer_finalizations, app.inventory_custody_counts,
  app.inventory_clinical_links, app.inventory_custody_reviews FROM PUBLIC, anon, authenticated;

CREATE FUNCTION app.guard_custody_workflow_evidence() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog AS $$
BEGIN
  RAISE EXCEPTION 'La evidencia de custodia es inmutable; registra una nueva evidencia';
END;
$$;
REVOKE ALL ON FUNCTION app.guard_custody_workflow_evidence() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER trg_transfer_finalizations_immutable
  BEFORE UPDATE OR DELETE ON app.inventory_transfer_finalizations
  FOR EACH ROW EXECUTE FUNCTION app.guard_custody_workflow_evidence();
CREATE TRIGGER trg_custody_counts_immutable
  BEFORE UPDATE OR DELETE ON app.inventory_custody_counts
  FOR EACH ROW EXECUTE FUNCTION app.guard_custody_workflow_evidence();
CREATE TRIGGER trg_clinical_links_immutable
  BEFORE UPDATE OR DELETE ON app.inventory_clinical_links
  FOR EACH ROW EXECUTE FUNCTION app.guard_custody_workflow_evidence();
CREATE TRIGGER trg_custody_reviews_immutable
  BEFORE UPDATE OR DELETE ON app.inventory_custody_reviews
  FOR EACH ROW EXECUTE FUNCTION app.guard_custody_workflow_evidence();
