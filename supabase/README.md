# Supabase Edge Functions — Aprovisionamiento de identidad

Versiona y documenta las Edge Functions que Spring invoca para crear y eliminar
usuarios en `auth.users` (Supabase Auth). Spring **nunca** usa el service role:
el `SUPABASE_SERVICE_ROLE_KEY` vive únicamente en el entorno de estas funciones.

## Contrato

### `POST /functions/v1/create-auth-user`

Autorización: `Authorization: Bearer <access_token del actor>`.

El actor debe estar `ACTIVE` en `app.users` y tener **`INSTITUTION_WRITE`**
(`SUPER_ADMIN`) o **`USER_MANAGE`** (`ADMIN_INSTITUTION`).

| Respuesta | Significado |
|---|---|
| `201 { id, email }` | Usuario creado en `auth.users` (email confirmado) |
| `401 UNAUTHORIZED` | Token ausente o inválido |
| `403 FORBIDDEN` | Actor sin permiso o inactivo |
| `409 EMAIL_ALREADY_EXISTS` | El correo ya está registrado |
| `400 BAD_REQUEST` | Email/password faltantes o contraseña < 8 caracteres |

```json
{ "email": "vacunador@hosp-a.com", "password": "Temp123!", "fullName": "Ana Vacunadora" }
```

La contraseña solo viaja en el request; nunca se registra ni se devuelve.

### `DELETE /functions/v1/delete-auth-user/{id}`

Misma autorización que `create-auth-user`. Usada por Spring como **compensación**
cuando falla la creación del espejo en `app.users`. Devuelve `200 { id }`.

## Autorización

1. `verify_jwt = true` (config.toml): la plataforma valida firma/expiración del JWT.
2. `auth.getUser(jwt)`: resuelve el `sub`.
3. RPC `public.is_permission_granted(uid, permission_code)`: verifica en
   `app.user_roles → role_permissions → permissions` que el usuario esté activo
   y tenga el permiso. Las tablas de negocio (`app.*`) **no** están expuestas a
   PostgREST; la RPC es `SECURITY DEFINER` (migration `V2__add_auth_function_rpc.sql`).

## Despliegue

Requisitos: Supabase CLI (`supabase`).

```bash
supabase functions deploy create-auth-user
supabase functions delete create-auth-user  # para eliminar (no recomendado)
```

La migration `V2__add_auth_function_rpc.sql` (Spring Flyway) crea la RPC
`public.is_permission_granted`. Sin ella, las funciones responden 500.