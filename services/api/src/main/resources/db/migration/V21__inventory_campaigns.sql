-- Jornadas organizan actividades; no representan stock ni cierran custodias.
CREATE TABLE app.inventory_campaigns (
    id UUID PRIMARY KEY,
    institution_id UUID NOT NULL REFERENCES app.institutions(id),
    name TEXT NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 200),
    location TEXT NOT NULL CHECK (length(btrim(location)) BETWEEN 1 AND 200),
    starts_on DATE NOT NULL,
    ends_on DATE NOT NULL CHECK (ends_on >= starts_on),
    status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'FINISHED')),
    created_by UUID NOT NULL REFERENCES app.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_by UUID REFERENCES app.users(id),
    finished_at TIMESTAMPTZ,
    CONSTRAINT uq_inventory_campaign_scope UNIQUE (institution_id, id),
    CONSTRAINT ck_inventory_campaign_finish CHECK (
      (status = 'ACTIVE' AND finished_by IS NULL AND finished_at IS NULL) OR
      (status = 'FINISHED' AND finished_by IS NOT NULL AND finished_at IS NOT NULL))
);
CREATE INDEX idx_inventory_campaign_scope ON app.inventory_campaigns(institution_id, starts_on);

CREATE TABLE app.inventory_campaign_participants (
    institution_id UUID NOT NULL,
    campaign_id UUID NOT NULL,
    vaccinator_id UUID NOT NULL REFERENCES app.users(id),
    added_by UUID NOT NULL REFERENCES app.users(id),
    added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (campaign_id, vaccinator_id),
    FOREIGN KEY (institution_id, campaign_id) REFERENCES app.inventory_campaigns(institution_id, id)
);

ALTER TABLE app.inventory_assignments ADD COLUMN campaign_id UUID;
ALTER TABLE app.inventory_assignments ADD CONSTRAINT fk_assignment_campaign_scope
    FOREIGN KEY (institution_id, campaign_id) REFERENCES app.inventory_campaigns(institution_id, id);
CREATE INDEX idx_inventory_assignments_campaign ON app.inventory_assignments(institution_id, campaign_id);
