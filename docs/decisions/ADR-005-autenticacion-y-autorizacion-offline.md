# ADR-005: Autenticacion y autorizacion offline

- Estado: Aceptada
- Fecha: 2026-08-24
- Alcance: autenticacion de Flutter, autorizacion de Spring Boot y trabajo offline

## Contexto

La aplicacion necesita autenticar usuarios con Supabase Auth y permitir que un
`VACCINATOR` continue registrando operaciones sin conectividad. La autenticacion
online y la autorizacion para trabajar offline son conceptos relacionados, pero
no son el mismo mecanismo.

El access token tiene una duracion corta. Por tanto, su expiracion no puede ser
la condicion que bloquee el trabajo offline durante la ventana autorizada.

## Decision

### Autenticacion online

- Flutter se autentica directamente contra Supabase Auth mediante
  `signInWithPassword`.
- Spring Boot nunca recibe ni almacena contrasenas.
- Supabase Auth crea la identidad en `auth.users`.
- Spring crea o completa el registro correspondiente en `app.users`.
- Un administrador asigna la institucion y los roles.
- Un usuario sin registro activo y completo en `app.users` no tiene acceso
  funcional a la aplicacion.
- Las rutas `/auth/login`, `/auth/refresh` y `/auth/logout` quedan fuera del
  contrato del API.

Despues de autenticarse, Flutter solicita el contexto autorizado:

```text
Flutter → Supabase Auth: signInWithPassword()
Supabase Auth → Flutter: access_token + refresh_token
Flutter → Spring: GET /api/v1/me con Bearer token
Spring → valida JWT y app.users
Spring → Flutter: perfil, institucion, roles, permisos y configuracion offline
```

Spring valida en `/api/v1/me`:

1. Firma y expiracion del JWT.
2. Identidad mediante `JWT.sub`.
3. Existencia y estado activo de `app.users`.
4. Institucion, roles, permisos y scope vigentes.

La identidad se obtiene del JWT. La autorizacion vigente se obtiene de Spring y
de la base de datos, no del body de la peticion ni de los claims como fuente
definitiva.

### Separacion de estado

Flutter mantiene dos conceptos separados:

```text
RemoteUserProfile
  id, email, name, institution, roles, permissions

LocalSessionState
  lastOnlineValidation
  offlineWindowHours
  token metadata
  local lock status
```

`RemoteUserProfile` representa lo ultimo que Spring autorizo. No es una fuente
de verdad permanente: puede quedar obsoleto hasta la siguiente validacion.

`LocalSessionState` controla si el usuario puede continuar trabajando sin red.
Estos datos se almacenan localmente; los secretos y tokens se guardan en
almacenamiento seguro, nunca en SQLite.

### Autorizacion offline

La autorizacion offline no verifica criptograficamente el JWT y no consulta
`app.users`, porque Flutter no puede hacer ninguna de esas operaciones de forma
confiable sin conectividad.

Flutter permite operaciones offline solo cuando se cumplen ambas condiciones:

```text
usuario local autenticado y desbloqueado
AND
now - lastOnlineValidation <= offlineWindowHours
```

La expiracion del access token no bloquea por si sola las operaciones offline.
El token se refresca cuando vuelve la conectividad. La autorizacion offline se
basa en la ultima respuesta valida de `/api/v1/me` y en la ventana configurada.

Si la ventana expira, Flutter pasa a `OFFLINE_LOCKED`: permite solo lectura
local y exige reconexion antes de crear nuevas operaciones.

La politica offline aplica por capacidad y rol. Solo `VACCINATOR` puede crear
operaciones clinicas offline. `ADMIN_INSTITUTION`, `SUPER_ADMIN` y las
operaciones administrativas requieren conectividad.

### Reconexion

Al detectar conectividad, Flutter ejecuta las acciones en este orden:

1. Refrescar la sesion de Supabase Auth si es necesario.
2. Solicitar `GET /api/v1/me`.
3. Validar usuario activo, institucion, permisos y scope vigentes.
4. Actualizar `RemoteUserProfile` y `lastOnlineValidation`.
5. Si la validacion es exitosa, procesar el outbox mediante `push`.
6. Aplicar el resultado de cada operacion: `COMPLETED`, `FAILED` o
   `QUARANTINED`.

El cliente nunca ejecuta `push` antes de completar correctamente `/me`.

### Usuario desactivado mientras trabaja offline

Si `/me` detecta que el usuario fue desactivado, perdio su institucion o ya no
tiene los permisos necesarios:

- Flutter bloquea nuevas operaciones offline.
- Flutter no ejecuta el `push` pendiente.
- Las operaciones pendientes se marcan localmente como `QUARANTINED` con
  motivo `USER_NOT_ACTIVE` o `AUTHORIZATION_CHANGED`.
- La sesion local se invalida y se solicita una nueva autenticacion cuando
  corresponda.
- El outbox no se elimina silenciosamente; queda disponible para revision.

El servidor mantiene una segunda barrera: si una operacion alcanza `/sync/push`
despues de que el usuario haya sido desactivado, Spring la rechaza, la registra
como cuarentenada y conserva la auditoria correspondiente.

## Consecuencias

### Positivas

- Spring concentra la autorizacion de negocio sin duplicar autenticacion.
- La expiracion corta del JWT no rompe el trabajo offline autorizado.
- `/me` detecta temprano cambios de estado antes de sincronizar datos.
- La desactivacion del usuario produce un estado visible y trazable.
- El flujo mantiene la separacion entre identidad remota y estado local.

### Negativas

- Flutter debe implementar almacenamiento seguro, bloqueo local y control de la
  ventana offline.
- La autorizacion local puede quedar obsoleta hasta la reconexion.
- Se necesitan pruebas de reconexion, desactivacion, cuarentena y expiracion
  de la ventana offline.

## Reglas de implementacion

- Spring valida JWT, usuario activo, permisos, institucion, scope y dominio en
  cada request protegido.
- La UI puede ocultar acciones, pero nunca autoriza.
- Toda operacion clinica offline se guarda atomica y conjuntamente con su
  entrada en el outbox.
- Toda operacion sincronizada se audita.
- Un JWT nunca se guarda en SQLite.
