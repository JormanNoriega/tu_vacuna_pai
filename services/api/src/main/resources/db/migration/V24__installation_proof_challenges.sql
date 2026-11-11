-- Infraestructura aislada: no autentica instalaciones ni habilita consumo offline.
CREATE TABLE app.inventory_installation_proof_challenges (
    id UUID PRIMARY KEY,
    institution_id UUID NOT NULL,
    actor_id UUID NOT NULL,
    installation_id UUID NOT NULL,
    public_key BYTEA NOT NULL CHECK (octet_length(public_key) BETWEEN 1 AND 128),
    nonce BYTEA NOT NULL CHECK (octet_length(nonce) = 32),
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    FOREIGN KEY (institution_id, installation_id, actor_id)
      REFERENCES app.inventory_installations(institution_id, id, vaccinator_id)
);
CREATE INDEX idx_installation_proof_challenge_expiry
    ON app.inventory_installation_proof_challenges(expires_at);
