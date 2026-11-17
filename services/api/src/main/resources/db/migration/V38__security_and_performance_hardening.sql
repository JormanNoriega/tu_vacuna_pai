-- V38: Endurecimiento de seguridad en RPCs y cobertura de indices para claves foraneas de inventario.

-- 1. Revocar permisos de ejecucion a roles no autorizados (anon y public) sobre funciones de seguridad
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = 'find_auth_user_by_operation') THEN
        REVOKE EXECUTE ON FUNCTION public.find_auth_user_by_operation(uuid) FROM PUBLIC, anon, authenticated;
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
            GRANT EXECUTE ON FUNCTION public.find_auth_user_by_operation(uuid) TO service_role;
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = 'list_provisioning_orphans') THEN
        REVOKE EXECUTE ON FUNCTION public.list_provisioning_orphans() FROM PUBLIC, anon, authenticated;
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
            GRANT EXECUTE ON FUNCTION public.list_provisioning_orphans() TO service_role;
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = 'is_app_super_admin') THEN
        REVOKE EXECUTE ON FUNCTION public.is_app_super_admin(uuid) FROM anon;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = 'is_permission_granted') THEN
        REVOKE EXECUTE ON FUNCTION public.is_permission_granted(uuid, text) FROM anon;
    END IF;
END
$$;

-- 2. Indices cubridores de claves foraneas en tablas de inventario (evitan table scans y bloqueos en cascada)
CREATE INDEX IF NOT EXISTS idx_inventory_assignments_dispatched_by
    ON app.inventory_assignments(dispatched_by);

CREATE INDEX IF NOT EXISTS idx_inventory_assignments_vaccinator_id
    ON app.inventory_assignments(vaccinator_id);

CREATE INDEX IF NOT EXISTS idx_inventory_receipts_received_by
    ON app.inventory_receipts(received_by);

CREATE INDEX IF NOT EXISTS idx_difference_resolutions_recorded_by
    ON app.inventory_difference_resolutions(recorded_by);

CREATE INDEX IF NOT EXISTS idx_difference_resolutions_scope_fk
    ON app.inventory_difference_resolutions(institution_id, lot_id, assignment_id);

CREATE INDEX IF NOT EXISTS idx_depot_regularizations_recorded_by
    ON app.inventory_depot_regularizations(recorded_by);

CREATE INDEX IF NOT EXISTS idx_lot_creation_created_by
    ON app.inventory_lot_creation_operations(created_by);

CREATE INDEX IF NOT EXISTS idx_lot_creation_scope_fk
    ON app.inventory_lot_creation_operations(institution_id, lot_id);
