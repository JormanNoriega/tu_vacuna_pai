# Implementación del Motor Offline (Fase 3)

- Estado: Hito 1 (motor offline móvil), Hito 2 (backend sync), Hito 3A (cableado local-first real) y Fase 2 backend (campos de paciente + catálogos de referencia) implementados. Pendiente: wizard "Nueva atención".
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

Hoy el motor offline móvil ya existe (Hito 1); el backend aún no expone sync:

- El móvil tiene Drift cifrado (`apps/mobile/lib/core/storage/app_database.dart`,
  `schemaVersion: 5`) con tablas clínicas (`PatientsLocal`, `AttentionsLocal`,
  `AppliedDosesLocal`) y outbox (`SyncOutbox`, `SyncOutboxDependencies`), además
  del módulo `lib/core/synchronization/` (`SyncEngine`, `SyncScheduler`,
  `SyncOutboxRepository`, `ClinicalOfflineRepository`).
- `offline_policy.dart` ya habilita `offlineAuthorized: true` en la cadena MVP.
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

- Backend: `/sync/push`, `/sync/pull` (cursor inclusivo sobre
  `processed_operations` enriquecida) y registro de auditoría de las operaciones
  sincronizadas.
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

> **Decisiones de implementación cerradas (2026-09-11).** Corrigen supuestos del
> plan original tras analizar el estado real del backend:
>
> - El pull se construye **enriqueciendo `processed_operations`** con
>   `institution_id` y el `payload` original del request (V11); no se usa
>   `audit_events` como fuente. El `sync_sequence` ya existe pero no estaba
>   mapeado en la entidad.
> - `COMPLETE_ATTENTION` se vuelve idempotente añadiendo `operationId` a
>   `AttentionService.complete` (hoy no registra en `processed_operations`, por lo
>   que un reintento fallaba con `INVALID_STATE`).
> - La sección `catalogs` del pull se **difiere**: `SyncPullResponse` en
>   `openapi.yaml` solo define `operations` + `nextCursor`, el móvil tolera su
>   ausencia y ya existe `/catalogs/effective`.
> - Los endpoints `/conflicts` y `/conflicts/{id}/resolve` se **difieren**; en
>   este hito el push solo crea el `PatientMergeRequest` en `PENDING_REVIEW`.
> - El scope del pull es la **institución del actor** (`DataScope`); el scope
>   granular de `sync_scopes` (municipio/departamento/ALL) queda para después.
> - `accepted[]` devuelve **`operation_id`** (no el response embebido), conforme a
>   `openapi.yaml:819-828`.

### B1. DTOs y `SyncController`

- `dto/`: `SyncOperation`, `SyncPushRequest`, `SyncPushResponse` (+
  `RejectedOperation`), `SyncPullResponse` — records según `openapi.yaml:781-838`.
- `controller/SyncController`, base `/api/v1/sync`:
  - `POST /push` → `SyncPushRequest` → `SyncPushResponse`.
  - `GET /pull?since={cursor}&limit={n}` → `SyncPullResponse`.
  - Solo exige autenticación; el permiso se valida **por comando** dentro del
    servicio (para poder rechazar con `PERMISSION_DENIED` sin abortar el batch).
  - Devuelve DTOs (cumple `ArchitectureTest`).

### B2. `SyncPushService`

- No es `@Transactional` a nivel de batch: cada comando se aplica en la
  transacción propia del servicio de dominio (atomicidad por operación).
- Procesa `operations` en el orden recibido (el cliente ya envía orden
  topológico) y valida dependencias:
  - ausente del batch y no procesada antes → `DEPENDENCY_NOT_FOUND`;
  - rechazada dentro del mismo batch → `DEPENDENCY_FAILED`.
- Idempotencia: `ProcessedOperationsService.find(operationId, ...)`; si existe,
  devuelve `accepted` sin reprocesar.
- Verifica permiso del comando resuelto (`AuthorizedUser.getPermissions()`); si
  falta → `PERMISSION_DENIED`.
- Despacha por `commandType` y mapea excepciones de dominio a `reason`.
- Devuelve `accepted[]` y `rejected[]` con `RejectedOperation.reason`/`error`.

### B3. Command handlers (reutilizan servicios existentes)

Mapea `payload` (JSON libre) a los DTOs existentes con `ObjectMapper`; **no
reimplementa reglas de dominio**.

| `command_type` | Servicio reutilizado |
| --- | --- |
| `CREATE_PATIENT` | `PatientService.create(actorId, operationId, CreatePatientRequest)` |
| `CREATE_ATTENTION` | `AttentionService.create(actorId, operationId, CreateAttentionRequest)` |
| `REGISTER_APPLIED_DOSE` | `AttentionService.registerDose(actorId, operationId, attentionId, RegisterDoseRequest)` |
| `COMPLETE_ATTENTION` | `AttentionService.complete(actorId, operationId, attentionId)` |

- `REGISTER_APPLIED_DOSE` toma `attentionId` del `payload` (no viaja en la URL).
- **IDs de cliente**: el servidor respeta el `aggregate_id` del cliente como PK
  del paciente/atención/dosis (`PatientService.create`, `AttentionService.create`
  y `registerDose` admiten un UUID opcional). Sin esto, el pull generaría un
  agregado con otro id y el working set local duplicaría la entidad. En el camino
  REST directo el id llega `null` y el servidor genera el UUID.
- El `payload` registrado de la dosis incluye `attentionId` (el DTO REST
  `RegisterDoseRequest` no lo tiene) para que el cliente pueda aplicar el pull.
- `DUPLICATE_BUSINESS_IDENTITY` en `CREATE_PATIENT` → crear `PatientMergeRequest`
  `PENDING_REVIEW` (deduplicando por institución+documento) y rechazar con esa
  razón (D11).
- Auditoría: la registran los propios servicios de dominio (`audit_events`).

### B4. `SyncPullService`

- Cursor compuesto `"{sync_sequence}|{created_at_iso}"`; consulta **inclusiva**
  sobre `sync_sequence` (`sync-contract.md` §Cursor).
- Fuente: `app.processed_operations` con `institution_id` del actor y
  `sync_sequence > cursor`, ordenado por `sync_sequence`, con `limit` (default
  500). Sin sección `catalogs` (diferida).
- Devuelve `operations[]` reconstruidos con el `payload` original + `nextCursor`.

### B5. Sección `catalogs` en el pull (diferida)

- El móvil ya obtiene catálogos por `/catalogs/effective` y su `catalogsApplier`
  es opcional. Se documenta como pendiente en el backlog; cuando se implemente,
  `SyncPullResponse` ganará la sección sin romper `operations`.

### B6. Conflictos y merge

- La tabla `app.patient_merge_requests` **ya existe** (`V9__create_attentions.sql:113`);
  no requiere migración nueva.
- En este hito solo se **crea** el registro al detectar duplicado
  (`duplicate_patient_id` = paciente existente, `canonical_patient_id` = null,
  `status` = `PENDING_REVIEW`).
- `GET /conflicts` y la resolución online quedan en el backlog.

### B7. Migración `V11__enrich_processed_operations.sql`

- `ALTER TABLE app.processed_operations`:
  - `ADD COLUMN institution_id UUID` (+ FK a `institutions`, índice);
  - `ADD COLUMN payload JSONB` (payload original del request, para el pull);
  - backfill de `institution_id` desde `patients`/`attentions`/`applied_doses`
    por `aggregate_id`; backfill de `payload` con `'{}'`.
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

## 5b. Hito 3A — Cableado local-first (implementado)

- `ClinicalOfflineRepository` expone una fachada de dominio (`findPatients`,
  `createPatientLocal`, `createAttentionLocal`, `registerDoseLocal`,
  `completeAttentionLocal`, `attentionLocalWithDoses`) que resuelve la
  institución del perfil local y devuelve entidades de dominio.
- `AttentionController` recibe `offlineRepository` y, con sesión
  `offlineAuthorized`, escribe la cadena clínica en Drift + outbox; con sesión
  online mantiene el camino online-first. Las cancelaciones/ediciones siguen
  online-only.
- `CatalogRepositoryImpl` persiste catálogo efectivo y geografía en
  `SyncMetadata` (JSON) con respaldo offline ante `ApiException`.
- `SyncEngine._applyPulledOperation` aplica al working set género, teléfono,
  email y dirección del paciente, y lote/etiqueta de dosis.
- `SyncScheduler` acepta `onAfterSync`; en `main.dart` refresca
  `SyncStatusController`. El dashboard muestra la insignia de sync (pendientes +
  "sincronizar ahora").
- Tests: `sync_engine_test.dart` (accepted/dedupe/quarantine/dependencia) y
  fachada de dominio en `clinical_offline_repository_test.dart`.

## 5c. Backend Fase 2 — campos de paciente y catálogos (implementado)

- Migraciones: `V12` (identidad/demografía/dirección/contacto/antecedentes/
  `attentions.complete_scheme`), `V13` (`patient_affiliation`,
  `patient_special_conditions`, `patient_user_condition`), `V14` (guardianes y
  dosis ampliadas), `V15` (`reference_catalogs` + `reference_options` con el seed
  de las listas del legacy). `V11` se hizo idempotente.
- Backend: entidades/repositorios de las nuevas tablas; `CreatePatientRequest`,
  `PatientResponse` y `PatientService` ampliados; `RegisterDoseRequest` y
  `AppliedDoseEntity` con `syringeLot`/`diluent`/`vialCount`/`customObservation`;
  endpoint `GET /api/v1/catalogs/reference`.
- Nota Jackson 3: los booleanos opcionales de request se declaran como `Boolean`
  (no primitivos) para tolerar payloads que los omiten.
- Verificación: `services/api/mvnw.cmd test` (125 tests).


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
- `services/api/mvnw.cmd test` (backend).
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
- Sección `catalogs` en `SyncPullResponse` y su `catalogsApplier` en el móvil.
- `GET /conflicts` y `/conflicts/{id}/resolve` (resolución online por
  `ADMIN_INSTITUTION`).
- Scope granular de `sync_scopes` (municipio/departamento/ALL) en el pull.
- Plan e implementación del wizard "Nueva atención" de 4 pasos sobre este motor.
