-- ============================================================
-- V2__add_auth_function_rpc.sql
-- RPCs de autorizacion usadas por las Edge Functions de
-- aprovisionamiento de identidad (create-auth-user / delete-auth-user).
--
-- Las tablas de negocio viven en el esquema app, que NO esta expuesto a
-- PostgREST por seguridad. Estas funciones (SECURITY DEFINER en public)
-- solo comprueban permisos; nunca exponen datos de negocio.
-- ============================================================

-- Comprueba si el usuario tiene un permiso vigente a traves de
-- user_roles -> role_permissions -> permissions. El estado activo del
-- usuario se valida tambien aqui (app.users.status = 'ACTIVE').
CREATE OR REPLACE FUNCTION public.is_permission_granted(
    uid uuid,
    permission_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = app, public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM app.users u
        JOIN app.user_roles ur        ON ur.user_id = u.id
        JOIN app.role_permissions rp  ON rp.role_id = ur.role_id
        JOIN app.permissions p        ON p.id = rp.permission_id
        WHERE u.id = uid
          AND u.status = 'ACTIVE'
          AND p.code = permission_code
    );
$$;

-- Compatibilidad: envoltura de la RPC usada por la version previa de las
-- Edge Functions (equivalia a exigir INSTITUTION_WRITE, es decir SUPER_ADMIN).
CREATE OR REPLACE FUNCTION public.is_app_super_admin(uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = app, public
AS $$
    SELECT public.is_permission_granted(uid, 'INSTITUTION_WRITE');
$$;

-- Exponer solo a los roles de Supabase; el service role las invoca con el
-- JWT del usuario, y anon/authenticated no deben poder usarlas con datos
-- arbitrarios (la RPC valida por uid, no es sensible por si sola). Los roles
-- de Supabase no existen en una base local Docker, por eso se conceden con
-- guarda.
REVOKE ALL ON FUNCTION public.is_permission_granted(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_app_super_admin(uuid) FROM PUBLIC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        GRANT EXECUTE ON FUNCTION public.is_permission_granted(uuid, text) TO anon;
        GRANT EXECUTE ON FUNCTION public.is_app_super_admin(uuid) TO anon;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        GRANT EXECUTE ON FUNCTION public.is_permission_granted(uuid, text) TO authenticated;
        GRANT EXECUTE ON FUNCTION public.is_app_super_admin(uuid) TO authenticated;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        GRANT EXECUTE ON FUNCTION public.is_permission_granted(uuid, text) TO service_role;
        GRANT EXECUTE ON FUNCTION public.is_app_super_admin(uuid) TO service_role;
    END IF;
END
$$;