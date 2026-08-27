-- ============================================================
-- V3__provisioning_operations.sql
-- Registro de operaciones de aprovisionamiento de identidad
-- (creacion de ADMIN_INSTITUTION / VACCINATOR).
--
-- Spring crea el usuario en auth.users (Edge Function) y el espejo en
-- app.users en dos pasos sin transaccion compartida. Esta tabla:
--   * da idempotencia (operationId generado por el movil y reenviado en
--     reintentos);
--   * deja trazabilidad de auditoria (quien, cuando, institucion, resultado);
--   * permite reconciliar estados parciales (huerfanos en auth.users).
--
-- La correlacion entre ambos sistemas se prueba por operation_id: la Edge
-- Function escribe el mismo valor en app_metadata del auth.user en la misma
-- llamada admin.createUser. Spring NUNCA reclama un huerfano por email.
-- ============================================================

CREATE TABLE app.provisioning_operations (
    operation_id    UUID        PRIMARY KEY,
    auth_user_id    UUID,
    email           TEXT        NOT NULL,
    full_name       TEXT        NOT NULL,
    institution_id  UUID        NOT NULL,
    role            TEXT        NOT NULL,
    actor_id        UUID        NOT NULL,
    status          TEXT        NOT NULL,
    attempts        SMALLINT    NOT NULL DEFAULT 1,
    error           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_prov_operations_institution FOREIGN KEY (institution_id)
        REFERENCES app.institutions (id),
    CONSTRAINT fk_prov_operations_actor FOREIGN KEY (actor_id)
        REFERENCES app.users (id),
    CONSTRAINT ck_prov_operation_status CHECK (status IN (
        'PENDING', 'AUTH_CREATED', 'MIRROR_CREATED', 'ROLE_ASSIGNED',
        'COMPLETED', 'COMPENSATING', 'COMPENSATED', 'COMPENSATION_FAILED',
        'REJECTED', 'UNCERTAIN'))
);

CREATE INDEX idx_prov_operations_status ON app.provisioning_operations (status);
CREATE INDEX idx_prov_operations_email  ON app.provisioning_operations (email);

-- ============================================================
-- RPCs de correlacion (SECURITY DEFINER en public).
--
-- Las tablas de negocio viven en el esquema app y las de identidad en auth;
-- ambos esquemas son de Supabase. Spring no necesita SELECT directo sobre
-- auth.users: estas funciones exponen solo la correlacion por operation_id y
-- nunca datos sensibles.
-- ============================================================

-- Devuelve el auth.user creado por una operacion usando el operation_id que la
-- Edge Function escribio en app_metadata. Vacia si la operacion no creo nada.
CREATE OR REPLACE FUNCTION public.find_auth_user_by_operation(op_id uuid)
RETURNS TABLE(auth_user_id uuid, email text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = auth, public
AS $$
    SELECT id, email
    FROM auth.users
    WHERE raw_app_meta_data ->> 'provisioning_operation_id' = op_id::text
    LIMIT 1;
$$;

-- Huerfanos de aprovisionamiento: auth.users con operation_id en metadata y sin
-- espejo en app.users. Spring los reconcilia solo cuando la operacion coincide
-- por operation_id (nunca por email).
CREATE OR REPLACE FUNCTION public.list_provisioning_orphans()
RETURNS TABLE(operation_id uuid, auth_user_id uuid, email text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = auth, app, public
AS $$
    SELECT
        (u.raw_app_meta_data ->> 'provisioning_operation_id')::uuid AS operation_id,
        u.id AS auth_user_id,
        u.email
    FROM auth.users u
    WHERE u.raw_app_meta_data ->> 'provisioning_operation_id' IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM app.users au WHERE au.id = u.id
      );
$$;

-- Los roles de Supabase no existen en una base local Docker; se conceden con
-- guarda. postgres es el rol de Spring; service_role cubre futuras Edge
-- Functions.
REVOKE ALL ON FUNCTION public.find_auth_user_by_operation(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_provisioning_orphans() FROM PUBLIC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres') THEN
        GRANT EXECUTE ON FUNCTION public.find_auth_user_by_operation(uuid) TO postgres;
        GRANT EXECUTE ON FUNCTION public.list_provisioning_orphans() TO postgres;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        GRANT EXECUTE ON FUNCTION public.find_auth_user_by_operation(uuid) TO service_role;
        GRANT EXECUTE ON FUNCTION public.list_provisioning_orphans() TO service_role;
    END IF;
END
$$;