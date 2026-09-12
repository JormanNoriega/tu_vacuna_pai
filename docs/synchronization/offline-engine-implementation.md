# Implementación del Motor Offline (Fase 3)

- Estado: Plan aprobado (decisiones D1–D12 cerradas)
- Fecha: 2026-09-11
- Autoridad semántica: [`sync-contract.md`](sync-contract.md)
- Contrato HTTP: [`docs/api/openapi.yaml`](../api/openapi.yaml) (`/sync/push`, `/sync/pull`, `SyncOperation`, `SyncPushResponse`, `SyncPullResponse`)
- Esquema local objetivo: [`docs/database/sqlite-schema.drift`](../database/sqlite-schema.drift)
- Prerrequisito de: el wizard "Nueva atención" ([`docs/domain/nueva-atencion-wizard-campos.md`](../domain/nueva-atencion-wizard-campos.md))

> Este documento es el **plan de implementación** del motor de guardado local
> (outbox + SyncEngine) y de los endpoints de sincronización. No redefine reglas
> de dominio: las toma de `sync-contract.md`. El wizard se construye **después**,
> escribiendo contra este motor.

---

## 1. Contexto

La app **no es offline de punta a punta**. Solo un subconjunto de las
operaciones clínicas del `VACCINATOR` es offline; el resto es online-only.

### 1.1 Frontera online / offline

| Ámbito | Modo | Referencia |
| --- | --- | --- |
| `SUPER_ADMIN` / `ADMIN_INSTITUTION`: crear instituciones, gestionar vacunas y catálogos, gestionar vacunadores, resolver conflictos | **Online 100%** (sin outbox) | `architecture.md:396-401, 419-427` |
| `VACCINATOR` clínico: `CREATE_PATIENT`, `CREATE_ATTENTION`, `REGISTER_APPLIED_DOSE`, `COMPLETE_ATTENTION` + lectura local | **Offline-first** | `architecture.md:421-427`, `sync-contract.md:290-292` |
| `VACCINATOR` clínico online-only: `UPDATE_PATIENT_CONTACT`, `CANCEL_ATTENTION`, `CANCEL_APPLIED_DOSE` | **Online** | `offline_policy.dart:32-50` |
| `READ_ONLY` | Solo lectura local (sin escritura) | `architecture.md:401, 425` |

Hoy el motor offline no existe:

- El móvil tiene Drift cifrado (`apps/mobile/lib/core/storage/app_database.dart`,
  `schemaVersion: 4`) pero **solo cachea** usuario, instituciones, usuarios,
  metadatos y catálogo de vacunas. No hay tablas clínicas ni outbox.
- `offline_policy.dart:32-50` marca **todas** las operaciones clínicas con
  `offlineAuthorized: false`.
- El backend tiene idempotencia (`processed_operations`, V8) y `sync_scopes`
  (V1), pero **no** tiene controladores `/sync/push` ni `/sync/pull`.

**Objetivo:** habilitar la cadena `CREATE_PATIENT → CREATE_ATTENTION →
REGISTER_APPLIED_DOSE → COMPLETE_ATTENTION` de forma offline-first, idempotente
y auditable, con pull de operaciones y catálogos. Las funciones administrativas
(crear clínicas, gestionar vacunas/catálogos y vacunadores) permanecen online.

Aclaración de esquema: `sync_operations` / `sync_operation_dependencies`
mencionadas en `architecture.md` **no se crean en el servidor**. El log de
operaciones para el pull es `app.processed_operations` (`sync_sequence BIGSERIAL`).
Las dependencias son un asunto exclusivo del cliente (orden topológico del batch).

---

## 2. Decisiones cerradas

| # | Decisión |
| --- | --- |
| D1 | Fase 1 recortada: solo campos que el backend persiste E2E |
| D2/D6 | Offline-first solo para las operaciones clínicas del `VACCINATOR`; el wizard escribe contra el motor local |
| D3 | Las dosis se persisten al Confirmar (Paso 4 del wizard) |
| D4 | `attentionDate` editable en Paso 1; "esquema completo" en la atención |
| D5 | Se retira `PatientWizardPage`; el Paso 1 asume el alta del paciente |
| D7 | Wizard en ruta full-screen con progreso + bottom nav |
| D8 | Motor offline primero, luego wizard |
| D9 | Cadena MVP: `CREATE_PATIENT → CREATE_ATTENTION → REGISTER_APPLIED_DOSE → COMPLETE_ATTENTION` |
| D10 | Solo los catálogos que exige la Fase 1 recortada |
| D11 | `DUPLICATE_BUSINESS_IDENTITY` → `QUARANTINED` + `PatientMergeRequest` |
| D12 | Borrador de atención local progresivo en Drift |

---

## 3. Alcance

**Incluye**

- Backend: `/sync/push`, `/sync/pull` (con sección `catalogs`), conflictos/merge
  y auditoría de operaciones sincronizadas.
- Móvil: tablas Drift clínicas + outbox, `SyncEngine`/`SyncScheduler`, clonado de
  catálogos, repositorios local-first, proyección de estado de sync en UI.
- Habilitar `offlineAuthorized: true` para las operaciones de la cadena MVP.

**No incluye**

- Funciones administrativas, online por diseño (no solo por fase): crear
  clínicas, gestionar vacunas/catálogos y gestionar vacunadores.
- `UPDATE_PATIENT_CONTACT` offline: editar un paciente existente es online-only
  en la Fase 1.
- Cancelaciones offline (`CANCEL_APPLIED_DOSE`, `CANCEL_ATTENTION`): siguen
  online-first en esta fase.
- Catálogos de Fase 2 (EPS, regímenes, contraindicaciones, reacciones, carnet,
  estados migratorio/orientación sexual, etc.) y sus campos de paciente.
- Campos de dosis sin soporte backend (`syringeLot`, `diluent`, `vialCount`,
  `customObservation`).
- El wizard "Nueva atención" (se planifica aparte, sobre este motor).

---

## 4. Backend (Spring Boot)

Paquete objetivo: `com.pai.api.synchronization` (hoy solo tiene `entity`,
`repository` y `service/ProcessedOperationsService`).

### B1. `SyncController`

`com.pai.api.synchronization.controller.SyncController`, base `/api/v1/sync`:

- `POST /push` → `SyncPushRequest` → `SyncPushResponse`.
- `GET /pull?since={cursor}&limit={n}` → `SyncPullResponse`.
- `@PreAuthorize` de lectura/escritura de atención y paciente según comando.
- DTOs según `openapi.yaml:781-838`.

### B2. `SyncPushService`

- Procesa `operations` en el orden recibido (topológico; el cliente ya ordenó).
- Por operación:
  1. Valida dependencias presentes (`DEPENDENCY_NOT_FOUND`/`DEPENDENCY_FAILED`).
  2. Idempotencia: `ProcessedOperationsService.find(operationId, ...)`; si existe,
     devuelve la respuesta original como `accepted`.
  3. Valida scope con `app.sync_scopes` (`architecture.md` §11.8).
  4. Despacha por `commandType`.
  5. `ProcessedOperationsService.record(...)` con la respuesta.
- Devuelve `accepted[]` y `rejected[]` con `RejectedOperation.reason`.

### B3. Command handlers (reutilizan servicios existentes)

Mapea `payload` (JSON libre) a los DTOs existentes:

| `command_type` | Servicio reutilizado |
| --- | --- |
| `CREATE_PATIENT` | `PatientService.create(actorId, operationId, CreatePatientRequest)` |
| `CREATE_ATTENTION` | `AttentionService.create(actorId, operationId, CreateAttentionRequest)` |
| `REGISTER_APPLIED_DOSE` | `AttentionService.registerDose(actorId, operationId, id, RegisterDoseRequest)` |
| `COMPLETE_ATTENTION` | `AttentionService.complete(actorId, id)` |

- `DUPLICATE_BUSINESS_IDENTITY` en `CREATE_PATIENT` → crear `PatientMergeRequest`
  y rechazar la operación con esa razón (D11).
- Registrar auditoría en `app.audit_events` con `client_operation_id`.

### B4. `SyncPullService`

- Cursor compuesto `"{sync_sequence}|{created_at_iso}"`; consulta **inclusiva**
  sobre `sync_sequence` (`sync-contract.md` §Cursor).
- Fuente: `app.processed_operations` con `sync_sequence > cursor`, filtrado por
  scope del actor.
- Devuelve `operations[]` + `nextCursor` + sección `catalogs` (B5).

### B5. Sección `catalogs` en el pull

- DTO `CatalogSnapshot`: geo (países/departamentos/municipios) + catálogo
  efectivo de vacunas de la institución.
- Extensible: en Fase 2 se agregan los catálogos nuevos sin cambiar el contrato
  de operaciones.
- Versionado por `catalogVersion` para que el cliente no recargue si no cambió.

### B6. Conflictos y merge

- Migración nueva: tabla `app.patient_merge_requests` (`id`, `source_patient_id`,
  `target_patient_id`, `institution_id`, `status`, `created_at`, `resolved_at`,
  `resolved_by`).
- `GET /conflicts` (ADMIN_INSTITUTION) y endpoint de resolución, según
  `openapi.yaml:518-525, 839-845`.
- La resolución es online (no entra al outbox).

### B7. Migración

- `V11__create_patient_merge_requests.sql` (la única tabla faltante; el registro
  temporal de operaciones ya existe).
- No crear `sync_operations`/`sync_operation_dependencies`.

---

## 5. Móvil (Flutter / Drift)

### M1. Esquema local (Drift `schemaVersion: 5`)

Materializar en `apps/mobile/lib/core/storage/app_database.dart` las tablas de
`docs/database/sqlite-schema.drift`:

- `PatientsLocal`, `PatientGuardiansLocal`
- `AttentionsLocal`, `AppliedDosesLocal`
- `SyncOutbox`, `SyncOutboxDependencies`

Reglas:

- Escritura **atómica** (transacción Drift) del agregado + su fila `SyncOutbox`.
- `syncState` por agregado para la proyección UI.
- `SyncMetadata` (ya existe) guarda `last_pull_cursor` y versiones de catálogo.
- Migración cifrada `onUpgrade` v4→v5 (ver riesgos).

### M2. Outbox

- Repositorio de outbox: encolar, leer pendientes en orden topológico, marcar
  `PROCESSING/COMPLETED/FAILED/QUARANTINED`, `retry_count`, `next_retry_at`.
- Al arranque del engine, cualquier `PROCESSING` se reinicia a `PENDING`
  (seguro por idempotencia del servidor).

### M3. `SyncEngine` + `SyncScheduler`

Estructura objetivo (`architecture.md:146-151`):

- `lib/core/synchronization/sync_engine.dart`
- `lib/core/synchronization/sync_scheduler.dart`
- `lib/core/synchronization/sync_queue.dart`
- `lib/core/synchronization/sync_operation.dart`
- `lib/core/synchronization/sync_status.dart`

Responsabilidades:

- Disparo por reconexión (`connectivity_plus`) y por arranque de sesión.
- Push de batch topológico; interpretar `accepted`/`rejected`; backoff exponencial
  para fallos transitorios; `QUARANTINED` sin reintento automático.
- Pull por cursor inclusivo, dedupe por `operation_id` y **aplicación de las
  operaciones recibidas al working set local** (ver M6).

### M4. Command payload builders

Construir el `payload` de cada comando desde el estado local (paciente, atención,
dosis), con `operation_id` (UUID v4) y `dependencies` explícitas.

### M5. Repositorios local-first

Refactorizar:

- `features/patients/data/patients_repository_impl.dart`
- `features/attentions/data/attentions_repository_impl.dart`

para leer/escribir local y encolar outbox, en lugar de llamar directo a la API.
El borrador de atención (Paso 4 del wizard, D3/D12) se persiste localmente de
forma progresiva.

### M6. Aplicar el pull: working set y catálogos

- **Working set (lectura offline):** al aplicar las operaciones del pull, hacer
  upsert en `PatientsLocal`, `AttentionsLocal` y `AppliedDosesLocal` filtrando
  por scope y deduplicando por `operation_id`. Esto es lo que permite **buscar y
  atender a un paciente existente sin internet** en el Paso 1 del wizard.
- **Catálogos (solo lectura):** aplicar la sección `catalogs` reemplazando
  `VaccinesCache`, `VaccineOptionsCache`, `InstitutionVaccinesCache`,
  `InstitutionVaccineOptionsCache` y la caché geo nueva.
- Guardar `catalogVersion` para evitar recargas.

### M7. Habilitar offline clínico

En `apps/mobile/lib/core/auth/offline_policy.dart:32-50`, cambiar a
`offlineAuthorized: true` **solo** en:

- `createPatient`, `createAttention`, `registerDose`, `completeAttention`.

Dejar en `false`:

- `updatePatient` (edición de contacto: online-only en Fase 1).
- `cancelAttention` y `cancelDose`.
- Todas las operaciones administrativas y de catálogo.

### M8. Proyección de estado de sync en UI

Derivar `LOCAL_ONLY / PENDING_SYNC / SYNCING / SYNCED / FAILED / QUARANTINED`
desde el outbox + sesión (`sync-contract.md` §Estados visibles). Vive en la capa
de presentación, no en los controladores (`architecture.md` §Controladores).

### M9. Wiring

Actualizar `apps/mobile/lib/main.dart` y `apps/mobile/lib/app/app.dart` para
inyectar `AppDatabase`, outbox, `SyncEngine`/`SyncScheduler` y los repos
local-first.

---

## 6. Orden de ejecución

Prioridad solicitada: **motor offline → backend y catálogos → GUI**.

| Hito | Contenido | Depende de |
| --- | --- | --- |
| 1 | **Motor offline móvil:** M1–M2 (Drift v5 + outbox), M3–M4 (`SyncEngine` + payload builders), M5 (repos local-first), M6 (working set) y M7 (habilitar offline) | — |
| 2 | **Backend y catálogos:** B1–B5, B7 (`/sync/push`, `/sync/pull`, sección `catalogs`, merge) y M6-catálogos | 1 |
| 3 | **GUI:** M8–M9 (estructura) y el wizard "Nueva atención" | 2 |

> El hito 1 puede desarrollarse y probarse con dobles/HTTP simulado, pero su
> verificación E2E completa requiere el hito 2 (endpoints reales).

**Punto de control:** al cerrar el hito 2, una atención completa (paciente +
dosis) creada offline debe sincronizar y no duplicarse al reintentar.

---

## 7. Verificación

- `flutter analyze` y `flutter test` (mobile).
- `gradlew test` (backend).
- **Pruebas espejo** Dart + Java con el mismo nombre (`sync-contract.md:305-319`):
  - `rejects_operation_without_accepted_dependency`
  - `replays_same_operation_id_returns_original_response`
  - `never_duplicates_attention_on_retry`
  - `pull_is_inclusive_on_sync_sequence`
  - `deduplicates_pull_by_operation_id`
  - `quarantines_pending_operations_when_user_deactivated`
  - `cannot_edit_completed_attention`
  - `cannot_update_applied_dose`
- Prueba de lectura offline: un paciente recibido por pull es encontrable en la
  búsqueda del Paso 1 sin red.
- Prueba manual E2E: crear paciente + atención + dosis en modo avión, reconectar,
  verificar `SYNCED` y ausencia de duplicados.

---

## 8. Riesgos y notas

- **Migración Drift cifrada v4→v5**: la base actual es solo caché; las tablas
  clínicas requieren estrategia de migración explícita y no deben perderse
  borradores. Ver `app_database.dart:180-205`.
- **Zona horaria**: `attentionDate`/`applicationDate` se capturan localmente;
  normalizar a UTC al construir el payload.
- **Cursor**: mantener el formato `seq|ISO` y la comparación inclusiva sobre
  `sync_sequence`.
- **Scope**: nunca tomar `institution_id` del body; derivarlo del actor y
  `sync_scopes`.
- **`consecutive`**: queda nulo hasta que el servidor confirme la atención.
- **DUPLICATE_BUSINESS_IDENTITY**: la operación se marca `QUARANTINED` y requiere
  revisión online del admin.

---

## 9. Backlog (fuera del alcance)

- `UPDATE_PATIENT_CONTACT` offline (edición de paciente).
- Cancelaciones offline (`CANCEL_APPLIED_DOSE`, `CANCEL_ATTENTION`).
- Catálogos de Fase 2 y campos de paciente asociados (segundo nombre/apellido,
  sexo `INDETERMINATE`, orientación sexual, país/lugar de nacimiento, migración,
  régimen/EPS, comuna, área, autorizaciones, contraindicaciones/reacciones,
  condición de usuaria, condiciones especiales, madre/cuidador completos).
- Campos de dosis: `syringeLot`, `diluent`, `vialCount`, `customObservation`.
- Plan e implementación del wizard "Nueva atención" de 4 pasos sobre este motor.
