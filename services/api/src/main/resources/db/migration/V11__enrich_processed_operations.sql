-- ============================================================
-- V11__enrich_processed_operations.sql
-- Enriquecimiento de app.processed_operations para el pull de
-- sincronizacion (Hito 2).
--
-- Contexto:
--   * processed_operations es el log de comandos clinicos terminados
--     con exito (idempotencia D3) y la fuente del cursor del pull.
--   * Hasta V8 solo guardaba la respuesta (response_payload). Para que
--     /sync/pull pueda reconstruir la operacion (SyncOperation.payload)
--     y filtrar por scope, se agregan:
--       - institution_id: alcance institucional de la operacion.
--       - payload:        cuerpo original del request.
--   * sync_sequence (BIGSERIAL) ya existe y es el cursor monotono.
--
-- Notas:
--   * institution_id queda nullable para filas historicas cuyo agregado
--     ya no exista; las filas nuevas siempre la traen.
--   * El backfill se deriva del agregado segun el command_type.
-- ============================================================

ALTER TABLE app.processed_operations
    ADD COLUMN institution_id UUID,
    ADD COLUMN payload JSONB;

-- CREATE_PATIENT -> institucion del paciente.
UPDATE app.processed_operations po
SET institution_id = p.institution_id
FROM app.patients p
WHERE po.command_type = 'CREATE_PATIENT'
  AND po.aggregate_id = p.id
  AND po.institution_id IS NULL;

-- CREATE_ATTENTION / COMPLETE_ATTENTION -> institucion de la atencion.
UPDATE app.processed_operations po
SET institution_id = a.institution_id
FROM app.attentions a
WHERE po.command_type IN ('CREATE_ATTENTION', 'COMPLETE_ATTENTION')
  AND po.aggregate_id = a.id
  AND po.institution_id IS NULL;

-- REGISTER_APPLIED_DOSE -> institucion de la atencion de la dosis.
UPDATE app.processed_operations po
SET institution_id = a.institution_id
FROM app.applied_doses d
JOIN app.attentions a ON a.id = d.attention_id
WHERE po.command_type = 'REGISTER_APPLIED_DOSE'
  AND po.aggregate_id = d.id
  AND po.institution_id IS NULL;

-- Filas historicas sin payload reconstruible.
UPDATE app.processed_operations
SET payload = '{}'::jsonb
WHERE payload IS NULL;

ALTER TABLE app.processed_operations
    ALTER COLUMN payload SET NOT NULL;

ALTER TABLE app.processed_operations
    ADD CONSTRAINT fk_processed_operations_institution FOREIGN KEY (institution_id)
        REFERENCES app.institutions (id);

-- Cursor del pull: operaciones por institucion ordenadas por sync_sequence.
CREATE INDEX idx_processed_operations_institution_seq
    ON app.processed_operations (institution_id, sync_sequence);
