# Contrato de sincronización (autoridad semántica)

- Estado: Diseño aprobado (Fase 0)
- Fecha: 2026-09-07
- Alcance: Flutter (SyncEngine/outbox) y Spring Boot (procesamiento de comandos)

> Este documento es la **autoridad semántica** de la sincronización offline.
> Define el *qué* y el *porqué* de cada regla, comando y estado. El contrato
> HTTP concreto (endpoints, status codes, JSON de transporte) vive en
> `docs/api/openapi.yaml` y **no redefine** las reglas aquí descritas: lo
> referencia y lo transporta.

## Principios

1. **Orientado a operaciones, no a "subir todo".** El móvil no sube el estado
   completo: sube un flujo de comandos que el servidor aplica de forma
   idempotente y atómica.
2. **Idempotencia total.** Cada operación lleva un `operation_id` que el
   servidor conoce de forma global y definitiva. Reenviar la misma operación
   nunca produce un efecto duplicado.
3. **El servidor es la autoridad.** Todo permiso, scope, invariante de dominio,
   estado global y auditoría se valida en Spring. El cliente solo mejora la
   experiencia local (ADR-002).
4. **Atomicidad por operación.** Cada comando se aplica en su propia
   transacción junto con su registro de idempotencia. Un fallo no revierte las
   operaciones ya aceptadas del mismo batch.
5. **Nada se pierde silenciosamente en el pull.** El cursor es compuesto y
   monotónico, y el cliente deduplica por `operation_id` como red de seguridad.

## Comandos de dominio (D1)

Los comandos son el contrato lógico. Son **9** y están definidos en
`docs/architecture/architecture.md` §11.4 y `docs/domain/invariants.md`.

| `command_type` | Agregado | Descripción | Atomicidad |
|---|---|---|---|
| `CREATE_PATIENT` | patient | Crear paciente | atómico |
| `UPDATE_PATIENT_CONTACT` | patient | Actualizar contacto (teléfono, email, dirección) | atómico |
| `UPDATE_PATIENT_IDENTITY` | patient | Actualizar identidad (nombres, fecha nacimiento); requiere justificación | atómico |
| `CREATE_ATTENTION` | attention | Crear atención vacía (`DRAFT`) | atómico |
| `UPDATE_ATTENTION` | attention | Modificar atención (solo `DRAFT`/`IN_PROGRESS`) | atómico |
| `REGISTER_APPLIED_DOSE` | applied_dose | Registrar dosis aplicada (append-only) | atómico |
| `COMPLETE_ATTENTION` | attention | Pasar atención a `COMPLETED` (bloquea edición) | atómico |
| `CANCEL_APPLIED_DOSE` | applied_dose | Anular dosis con motivo (append-only) | atómico |
| `CANCEL_ATTENTION` | attention | Anular atención con motivo | atómico |

### Estructura común de un comando

```jsonc
{
  "operation_id": "uuid-v4",          // clave de idempotencia (única global)
  "command_type": "REGISTER_APPLIED_DOSE",
  "aggregate_id": "uuid-atencion",    // UUID del agregado afectado
  "payload": { /* campos específicos del comando */ },
  "dependencies": ["uuid-0"]          // opcional; operation_id de operaciones previas
}
```

### Reglas de dominio aplicadas por el servidor (invariantes)

- `Attention` `COMPLETED` es inmutable; no se acepta `UPDATE_ATTENTION`.
- `Attention` se completa solo desde un estado válido (`DRAFT`/`IN_PROGRESS`).
- Una atención anulada no recibe nuevas dosis.
- `AppliedDose` es append-only: no existe edición ni borrado; una corrección es
  `CANCEL_APPLIED_DOSE` (con motivo) + nueva `REGISTER_APPLIED_DOSE`.
- Todo paciente lleva UUID. `operation_id` y `aggregate_id` son UUID v4.

## Estados del outbox (cliente)

Viven en SQLite (`sync_outbox`). Son el ciclo de vida **local** de una operación.

| Estado | Significado | Transición |
|---|---|---|
| `PENDING` | Creada y lista para enviar. | → `PROCESSING` al intentar push |
| `PROCESSING` | En envío. **Estado local y transitorio.** | → `COMPLETED`/`FAILED`/`QUARANTINED`; o vuelve a `PENDING` por timeout |
| `COMPLETED` | Confirmada por el servidor (`accepted`). | terminal |
| `FAILED` | Rechazada por el servidor; puede requerir corrección. | → `PENDING` si se corrige (reintento manual) |
| `QUARANTINED` | Retenida para revisión (p. ej. usuario desactivado). | revisión manual |

### Definición de `PROCESSING`

`PROCESSING` **no** es un estado persistente del servidor. Es únicamente un
estado local del outbox que marca que una operación está siendo enviada. Como
el cliente puede desaparecer (apagón, crash, cierre de app) durante el envío,
**ninguna** lógica asume que una operación quedó en `PROCESSING` para siempre.

Recuperación:

1. El cliente marca `PROCESSING` justo antes del `POST /sync/push`.
2. Si la respuesta llega, la operación pasa a `COMPLETED`, `FAILED` o
   `QUARANTINED`.
3. Si no llega respuesta (timeout/error de transporte), la operación vuelve a
   `PENDING` y se reintenta según la política de backoff.
4. Ante un arranque de la app o del SyncEngine, cualquier operación que quedó
   en `PROCESSING` se reinicia a `PENDING`. Es seguro porque la idempotencia del
   servidor absorbe el reenvío.

En PostgreSQL **no** existe un estado "en progreso": `processed_operations`
solo registra operaciones **terminadas con éxito** (ver Idempotencia).

## Estados visibles en la UI

Son una proyección del outbox + estado de la sesión. No son un estado extra del
outbox; se derivan.

| Estado UI | Derivación |
|---|---|
| `LOCAL_ONLY` | Agregado existe localmente; aún no se generó operación de outbox (o pendiente de crear). |
| `PENDING_SYNC` | Outbox en `PENDING`/`PROCESSING`. |
| `SYNCING` | Outbox en `PROCESSING` (opcional: el usuario percibe el envío). |
| `SYNCED` | Outbox en `COMPLETED`. |
| `FAILED` | Outbox en `FAILED`. |
| `QUARANTINED` | Outbox en `QUARANTINED`. |
| `STALE` | Lectura cacheada que no se confirma recientemente (datos de catálogo/lectura, no operaciones). |
| `ONLINE_REQUIRED` | Operación bloqueada por falta de conexión (rol online-first o ventana vencida). |

## Idempotencia (D3)

- Cada operación lleva `operation_id` (UUID v4) generado por el cliente.
- El servidor persiste `processed_operations`:

  ```text
  processed_operations:
    - operation_id        (PK, único global)
    - command_type
    - aggregate_id
    - response_payload    (JSON de la respuesta original)
    - sync_sequence       (BIGINT global asignado por el servidor)
    - created_at          (ISO UTC)
  ```

- Al recibir un push con un `operation_id` ya registrado, el servidor **no
  reprocesa**: devuelve `200` con el `response_payload` original. Esto cubre el
  escenario de reintento tras perder la respuesta (push 09:31 → respuesta
  perdida → push 09:32 → se devuelve la original, sin duplicar).

### Retención

- `processed_operations` se retiene **6 meses** (cubre cualquier ventana
  offline permitida con margen amplio).
- Purga: cron mensual que elimina registros con `created_at < now() - 6 meses`.
- Riesgo de retención menor: si un dispositivo inactivo > 6 meses reintenta una
  operación purgada, el servidor la trataría como nueva (posible duplicado).
  Aceptado como límite operativo documentado.

## Dependencias (D12)

- Grafo simple: cadena opcional `dependencies: ["operation_id", ...]`.
- El cliente envía el batch **en orden topológico** (las dependencias primero).
- El servidor procesa en ese orden. No acepta dependencias hacia adelante.

| Situación | Resultado |
|---|---|
| Dependencia aceptada | Se procesa la operación siguiente |
| Dependencia ausente | `REJECTED` / `DEPENDENCY_NOT_FOUND` |
| Dependencia fallida | operaciones dependientes `REJECTED` / `DEPENDENCY_FAILED` |
| `operation_id` repetido | se devuelve la respuesta original, no se reprocesa |

Cadena MVP:

```text
CREATE_PATIENT → CREATE_ATTENTION → REGISTER_APPLIED_DOSE
```

## Dos caminos de transporte del mismo comando

Cada comando puede llegar al servidor por **dos rutas HTTP** (definidas en
`docs/api/openapi.yaml`):

1. **Endpoint REST directo**: p. ej. `POST /patients` transporta
   `CREATE_PATIENT`, `POST /attentions/{id}/doses` transporta
   `REGISTER_APPLIED_DOSE`. Es el camino **online-first** (admin, ediciones
   directas, resolución de conflictos).
2. **`POST /sync/push`**: transporta un batch de comandos con sus
   `operation_id`. Es el camino del **outbox offline**.

Ambos caminos **comparten la misma semántica y la misma idempotencia** por
`operation_id` (misma tabla `processed_operations`). No son reglas distintas:
son dos transportes del mismo contrato lógico. La única diferencia es que
`/sync/push` acepta dependencias y orden topológico; los endpoints directos
operan sobre un único comando cuya dependencia ya está resuelta (el recurso
padre se referencia por URL).

## Push (cliente → servidor)

Transporte HTTP en `docs/api/openapi.yaml`. Semántica aquí.

- El cliente sube un batch de operaciones (idealmente la cadena completa).
- **Atomicidad por operación**: cada comando se aplica en su propia transacción
  (agregado + `processed_operations`). Un fallo en una operación no revierte
  las anteriores del mismo batch; el cliente reintenta o corrige las rechazadas.
- Respuesta: lista de `accepted[]` y lista de `rejected[]` con motivo y error.
- `operation_id` ya conocido → `accepted` con la respuesta original.

### Razones de rechazo

| Razón | Significado | Acción cliente |
|---|---|---|
| `DEPENDENCY_NOT_FOUND` | Falta una dependencia | Reordenar y reintentar |
| `DEPENDENCY_FAILED` | Una dependencia falló | Corregir primero la dependencia |
| `DUPLICATE_BUSINESS_IDENTITY` | Paciente con el mismo documento ya existe | Crear `PatientMergeRequest` (admin) |
| `PERMISSION_DENIED` | El permiso actual no autoriza | Mostrar `QUARANTINED` |
| `USER_NOT_ACTIVE` | El usuario fue desactivado | Pasar pendientes a `QUARANTINED` |
| `INVALID_STATE` / `INVALID_PAYLOAD` | Violación de invariante | Corregir y reintentar |

## Pull (servidor → cliente)

Transporte HTTP en `docs/api/openapi.yaml`. Semántica aquí.

- `GET /api/v1/sync/pull?since={cursor}` devuelve operaciones del scope del
  usuario que el cliente aún no ha visto, más el nuevo cursor.
- El pull trae operaciones y actualizaciones (p. ej. catálogos, resoluciones de
  merge) que el cliente debe reflejar localmente.

### Cursor (compuesto, monotónico)

Para evitar el bug de perder operaciones en un pull incremental, el cursor **no
es solo un timestamp**. Es compuesto:

```text
cursor = { sync_sequence: BIGINT, created_at: ISO UTC }
```

- `sync_sequence`: BIGINT global, asignado por el servidor al aceptar una
  operación. Estrictamente creciente y sin huecos de ordenación.
- `created_at`: ISO UTC, para auditoría y depuración.

Reglas de consulta:

1. El servidor devuelve operaciones con `sync_sequence > cursor.sync_sequence`.
2. La condición es **inclusiva** sobre `sync_sequence` (no sobre `created_at`),
   por lo que dos operaciones con el mismo `created_at` nunca causan saltos.
3. El cliente guarda el último `next_cursor` recibido y lo reenvía en el
   siguiente pull.
4. **Red de seguridad**: el cliente **deduplica por `operation_id`** al aplicar
   los resultados del pull, de modo que una operación recibida dos veces (p. ej.
   por reenvío del cursor) se aplica una sola vez.

El cursor se persiste localmente (metadatos de sync) y sobrevive reinicios.

## Sync scope (D9)

- El servidor calcula el alcance a partir del usuario autenticado y de
  `sync_scopes` (institución / municipio / departamento). Nunca se toma del body
  (ADR-002 / architecture §11.8).
- El pull filtra por ese scope. El push valida que el `aggregate_id` de cada
  operación pertenezca al scope del usuario.

## Conflicto y duplicidad (D6)

- **Identidad duplicada**: si ya existe un paciente con el mismo
  `document_type + document_number` pero el cliente envía uno distinto, el
  servidor responde `DUPLICATE_BUSINESS_IDENTITY`, crea un
  `PatientMergeRequest` y lo deja pendiente para resolución por
  `ADMIN_INSTITUTION` (online).
  - Se preservan ambos historiales de atención.
  - Se consolidan los contactos.
  - La identidad canónica la decide el admin.
- **Registro modificado por dos clientes**: ver matriz en
  `architecture.md` §11.10 / §12.1:
  - Patient (contacto): merge con trazabilidad.
  - Patient (identidad): SERVER WINS + motivo.
  - Attention: SERVER WINS si ya está `COMPLETED`.
  - AppliedDose: append-only, sin conflicto.
  - Catálogos: no se modifican desde offline.

## Fuente de verdad por tipo de dato (D11)

| Tipo de dato | Autoridad | ¿Modificable offline? |
|---|---|---|
| Identidad del paciente | Servidor | Sí (local), pero el servidor gana en conflicto |
| Contacto del paciente | Servidor (merge) | Sí |
| Atención (`DRAFT`/`IN_PROGRESS`) | Servidor | Sí |
| Atención `COMPLETED`/`CANCELLED` | Servidor | No (inmutable) |
| Dosis aplicada | Servidor (append-only) | Sí (solo registrar/cancelar) |
| Catálogos de vacunas | Servidor | No (caché de solo lectura) |
| Usuarios/roles/permisos | Servidor | No |

## Autorización offline vs. sincronización (separación de conceptos)

Son dos problemas distintos y se tratan por separado:

1. **Autorización offline** (¿puedo trabajar sin red?): la resuelve
   `OfflinePolicy` + `OfflineAuthorizationService` (ventana
   `last_online_validation` vs `offline_window_hours`). Ya implementado.
2. **Sincronización** (¿hay operaciones locales sin subir?): la resuelve el
   SyncEngine contra este contrato. A construir en Fases 3-4.

Una operación offline solo entra al outbox si el rol tiene capacidad de
escritura offline (`offlineAuthorized: true` en `OperationPermission`). Las
operaciones clínicas se marcarán así en la Fase 4; las administrativas siguen
online-first sin outbox (architecture §11.12).

## Política de reintentos (backoff)

- Tras `FAILED` transitorio (red, 5xx), la operación vuelve a `PENDING` y se
  reintenta con backoff exponencial.
- `next_retry_at` y `retry_count` controlan el ritmo y el tope.
- Tras un límite de reintentos sin éxito por error de red, la operación se marca
  `FAILED` y se ofrece reintento manual o se conserva `PENDING` (decisión de
  configuración del cliente).
- `QUARANTINED` (usuario desactivado, permiso revocado) no se reintenta
  automáticamente; requiere revisión.

## Pruebas espejo obligatorias

Los casos críticos deben existir en Dart y Java con el mismo nombre y resultado
esperado (ver `docs/domain/invariants.md` §Pruebas espejo). Casos añadidos por
este contrato:

```text
rejects_operation_without_accepted_dependency
replays_same_operation_id_returns_original_response
never_duplicates_attention_on_retry
pull_is_inclusive_on_sync_sequence
deduplicates_pull_by_operation_id
quarantines_pending_operations_when_user_deactivated
cannot_edit_completed_attention
cannot_update_applied_dose
```
