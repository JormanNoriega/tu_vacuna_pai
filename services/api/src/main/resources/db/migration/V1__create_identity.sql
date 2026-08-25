-- ============================================================
-- V1__create_identity.sql
-- Modulo identity: instituciones, usuarios, roles, permisos
-- y alcances de sincronizacion.
--
-- Supabase Auth gestiona auth.users. Spring mantiene el espejo en
-- app.users (mismo UUID) y nunca escribe en auth.users.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS app;

-- ---------- Institutions ----------
CREATE TABLE app.institutions (
    id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    code                 TEXT        NOT NULL,
    name                 TEXT        NOT NULL,
    status               TEXT        NOT NULL DEFAULT 'ACTIVE',
    offline_window_hours SMALLINT    NOT NULL DEFAULT 72,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_institutions_code UNIQUE (code),
    CONSTRAINT ck_institution_status CHECK (status IN ('ACTIVE', 'INACTIVE')),
    CONSTRAINT ck_institution_offline_window CHECK (
        offline_window_hours > 0 AND offline_window_hours <= 168
    )
);

-- ---------- Users (espejo de auth.users) ----------
CREATE TABLE app.users (
    id             UUID        PRIMARY KEY,
    email          TEXT        NOT NULL,
    full_name      TEXT        NOT NULL,
    institution_id UUID        NOT NULL,
    status         TEXT        NOT NULL DEFAULT 'ACTIVE',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_users_auth_users FOREIGN KEY (id) REFERENCES auth.users (id),
    CONSTRAINT fk_users_institution FOREIGN KEY (institution_id)
        REFERENCES app.institutions (id),
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT ck_user_status CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

CREATE INDEX idx_users_institution ON app.users (institution_id);

-- ---------- Roles ----------
CREATE TABLE app.roles (
    id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    CONSTRAINT uq_roles_code UNIQUE (code)
);

-- ---------- Permissions ----------
CREATE TABLE app.permissions (
    id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    CONSTRAINT uq_permissions_code UNIQUE (code)
);

-- ---------- UserRoles ----------
CREATE TABLE app.user_roles (
    user_id    UUID        NOT NULL,
    role_id    UUID        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_user_roles PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES app.users (id),
    CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) REFERENCES app.roles (id)
);

CREATE INDEX idx_user_roles_role ON app.user_roles (role_id);

-- ---------- RolePermissions ----------
CREATE TABLE app.role_permissions (
    role_id       UUID        NOT NULL,
    permission_id UUID        NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_role_permissions PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_role_permissions_role FOREIGN KEY (role_id) REFERENCES app.roles (id),
    CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id)
        REFERENCES app.permissions (id)
);

CREATE INDEX idx_role_permissions_permission ON app.role_permissions (permission_id);

-- ---------- SyncScopes ----------
-- Alcance de autorizacion operativa para sincronizacion, calculado por Spring.
-- No define que conjunto de datos se replica en el dispositivo: esa politica
-- pertenece al modulo de sincronizacion.
CREATE TABLE app.sync_scopes (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID        NOT NULL,
    institution_id UUID        NOT NULL,
    scope_type     TEXT        NOT NULL,
    scope_value    UUID,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    effective_to   TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_sync_scopes_user FOREIGN KEY (user_id) REFERENCES app.users (id),
    CONSTRAINT fk_sync_scopes_institution FOREIGN KEY (institution_id)
        REFERENCES app.institutions (id),
    CONSTRAINT ck_sync_scope_type CHECK (
        scope_type IN ('INSTITUTION', 'MUNICIPALITY', 'DEPARTMENT', 'ALL')
    )
);

CREATE INDEX idx_sync_scopes_user ON app.sync_scopes (user_id);
CREATE INDEX idx_sync_scopes_institution ON app.sync_scopes (institution_id);

-- ============================================================
-- Seed: roles y permisos iniciales
-- ============================================================

INSERT INTO app.roles (code, name) VALUES
    ('SUPER_ADMIN',        'Super administrador global'),
    ('ADMIN_INSTITUTION',  'Administrador de institucion'),
    ('VACCINATOR',         'Vacunador'),
    ('READ_ONLY',          'Consulta unicamente');

INSERT INTO app.permissions (code, name) VALUES
    ('PATIENT_READ',       'Leer pacientes'),
    ('PATIENT_WRITE',      'Registrar y modificar pacientes'),
    ('ATTENTION_READ',     'Leer atenciones'),
    ('ATTENTION_CREATE',   'Crear atenciones'),
    ('CATALOG_READ',       'Leer catalogos'),
    ('CATALOG_WRITE',      'Escribir catalogos globales'),
    ('INSTITUTION_WRITE',  'Administrar instituciones'),
    ('INVENTORY_READ',     'Leer inventario'),
    ('INVENTORY_WRITE',    'Gestionar inventario'),
    ('USER_READ',          'Leer usuarios'),
    ('USER_MANAGE',        'Administrar usuarios'),
    ('MERGE_RESOLVE',      'Resolver fusiones de pacientes');

-- SUPER_ADMIN: todos los permisos, alcance global.
-- ADMIN_INSTITUTION, VACCINATOR y READ_ONLY: solo sus permisos definidos.
INSERT INTO app.role_permissions (role_id, permission_id)
SELECT role.id, perm.id
FROM app.roles role
JOIN app.permissions perm ON
    role.code = 'SUPER_ADMIN'
    OR (role.code = 'ADMIN_INSTITUTION' AND perm.code IN (
        'PATIENT_READ', 'PATIENT_WRITE', 'CATALOG_READ',
        'INVENTORY_READ', 'INVENTORY_WRITE', 'USER_READ',
        'USER_MANAGE', 'ATTENTION_READ', 'MERGE_RESOLVE'))
    OR (role.code = 'VACCINATOR' AND perm.code IN (
        'PATIENT_READ', 'PATIENT_WRITE',
        'ATTENTION_READ', 'ATTENTION_CREATE', 'CATALOG_READ'))
    OR (role.code = 'READ_ONLY' AND perm.code IN (
        'PATIENT_READ', 'ATTENTION_READ', 'CATALOG_READ'));
