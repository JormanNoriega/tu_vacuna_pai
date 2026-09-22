# Implementación del Módulo Clínico

> Documento de implementación para `patients`, `attentions` y `applied_doses`.
> Análogo a `vaccine-catalog-implementation.md`. Debe aprobarse antes de tocar código.

---

## 1. Decisiones de diseño y mejores prácticas

### 1.1 Scope del paciente: ¿`institution_id` o identidad nacional?

**Recomendación: `Patient` lleva `institution_id` (pertenencia institucional al crearlo).**

**Por qué:**
- **Consistencia con `DataScope` y `InstitutionScope` ya implementados**: el backend deriva el alcance del actor (`restricted` vs `unrestricted`). Si el paciente no tiene institución, no se puede validar `ScopeViolationException` al consultarlo.
- **Sync scope = institución**: el pull ya filtra por `institution_id` del usuario autenticado (`sync-contract.md` §Sync Scope). Un paciente sin institución rompería el filtrado de pull y la autorización offline.
- **Merge cross-institution por documento**: si dos instituciones registran el mismo `document_type + document_number`, el servidor detecta colisión (`DUPLICATE_BUSINESS_IDENTITY`), crea `PatientMergeRequest` y lo resuelve el `ADMIN_INSTITUTION` de **cada institución involucrada**. El paciente original conserva su `institution_id` creadora; el merge consolida contactos e historial clínico, pero la pertenencia no cambia.
- **Evita ambigüedad en auditoría y RLS**: cada registro clínico sabe inequívocamente de qué institución proviene.

**Implicación en esquema:**
```sql
CREATE TABLE app.patients (
    id                   UUID PRIMARY KEY,
    institution_id       UUID NOT NULL REFERENCES app.institutions(id),
    document_type        TEXT NOT NULL,
    document_number      TEXT NOT NULL,
    first_name           TEXT NOT NULL,
    last_name            TEXT NOT NULL,
    birth_date           DATE NOT NULL,
    sex                  TEXT NOT NULL CHECK (sex IN ('MALE', 'FEMALE')),
    -- demografia (gender como dato demografico, distinto de sex biologico)
    -- contactos, direcciones, tutores, antecedentes en tablas hijas
    version              BIGINT NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_patient_document_type CHECK (
        document_type IN ('CC', 'TI', 'CE', 'PASAPORTE')),  -- mismos tipos que V4 (app.users)
    CONSTRAINT uq_patient_identity_per_institution UNIQUE (institution_id, document_type, document_number)
);
```

> Nota: el índice único es **por institución**, no global. Permite que el mismo documento exista en dos instituciones (caso real: paciente atendido en dos redes). El merge posterior consolida.
> `document_type` usa los mismos valores que `app.users` (V4): `CC`, `TI`, `CE`, `PASAPORTE`. `sex` es el sexo biológico para reglas clínicas; `gender` vive en `patient_demographics` como dato demográfico (distinción ya definida en `architecture.md` §6.2).

---

### 1.2 Snapshot de `AppliedDose` contra el catálogo real

**Recomendación: snapshot completo de texto + versión de catálogo en cada dosis registrada.**

El catálogo actual tiene dos capas:
- **Globales** (`vaccine_options`): `dose` (ej. "Primera dosis", "Refuerzo") + `pneumococcalType` (ej. "PCV13", "PPSV23").
- **Institucionales** (`institution_vaccine_options`): operativas (`laboratory`, `syringe`, `dropper`, `observation`, etc.) copiadas desde `vaccine_option_templates` al habilitar la vacuna.

**Estructura del snapshot en `applied_doses`:**
```sql
CREATE TABLE app.applied_doses (
    id                     UUID PRIMARY KEY,
    attention_id           UUID NOT NULL REFERENCES app.attentions(id),
    vaccine_id             UUID NOT NULL REFERENCES app.vaccines(id),
    -- NOTA: app.vaccine_schedules NO existe todavia (V5 no la crea).
    -- El snapshot usa directamente la dosis global (vaccine_options dose).
    application_date       TIMESTAMPTZ NOT NULL,
    lot_number             TEXT,
    -- Opciones globales seleccionadas (id + snapshot texto):
    dose_option_id         UUID REFERENCES app.vaccine_options(id),
    pneumococcal_type_option_id UUID REFERENCES app.vaccine_options(id),
    -- Snapshots de catálogo (texto inmutable):
    vaccine_name_snapshot  TEXT NOT NULL,
    vaccine_code_snapshot  TEXT NOT NULL,
    dose_label_snapshot    TEXT NOT NULL,           -- display_name de vaccine_options (dose)
    dose_value_snapshot    TEXT,                    -- value de la opción dose (canónico)
    pneumococcal_type_snapshot TEXT,               -- display_name de vaccine_options (pneumococcalType) si aplica
    catalog_version        BIGINT NOT NULL,         -- version de vaccines al momento
    -- Opciones operativas elegidas en la atención (id + texto de opción institucional):
    selected_laboratory_id      UUID REFERENCES app.institution_vaccine_options(id),
    selected_laboratory_snapshot  TEXT,
    selected_syringe_id         UUID REFERENCES app.institution_vaccine_options(id),
    selected_syringe_snapshot     TEXT,
    selected_dropper_id         UUID REFERENCES app.institution_vaccine_options(id),
    selected_dropper_snapshot     TEXT,
    selected_observation_id       UUID REFERENCES app.institution_vaccine_options(id),
    selected_observation_snapshot TEXT,
    -- Estados append-only:
    status                 TEXT NOT NULL DEFAULT 'REGISTERED' CHECK (status IN ('REGISTERED', 'CANCELLED')),
    cancelled_reason       TEXT,
    cancelled_by           UUID REFERENCES app.users(id),
    cancelled_at           TIMESTAMPTZ,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Reglas:**
- Al registrar la dosis, el backend **copia** los `display_name` vigentes de las opciones globales e institucionales al snapshot. Si luego el admin cambia el nombre de una opción, las dosis ya aplicadas conservan el texto original.
- `catalog_version` = `vaccines.version` al momento del registro. Permite detectar en UI si el catálogo cambió post-registro.
- Las opciones operativas se eligen desde `institution_vaccine_options` (scope institución). El front envía los `id` elegidos; el backend valida que pertenezcan a la institución del actor y a la vacuna, y copia los `display_name` al snapshot.
- Las opciones globales (`dose`, `pneumococcalType`) guardan su `option_id` (`vaccine_options.id`) más el snapshot de texto, para trazabilidad exacta de qué opción se aplicó incluso si luego se renombra o desactiva.
- `field_type` reales: `dose` y `pneumococcalType` (globales, `vaccine_options`) + `laboratory`, `syringe`, `dropper`, `observation` (institucionales, `institution_vaccine_options`). Ver V5.
- **No se usa `vaccine_schedules`** hasta que esa tabla se implemente (está solo en el plan de arquitectura, no en las migraciones). Si en el futuro se agrega `VaccineSchedule`, se puede sumar `schedule_id` y su snapshot.

---

### 1.3 Idempotencia por `operation_id` en REST directos

**Recomendación: todos los endpoints de escritura clínica aceptan `operation_id` (header `Idempotency-Key` o campo en body) y usan la tabla `processed_operations` compartida con `/sync/push`.**

**Por qué:**
- `sync-contract.md` §Idempotencia y §Dos caminos de transporte: **ambos caminos comparten la misma semántica y la misma idempotencia** por `operation_id` (misma tabla `processed_operations`).
- El cliente Flutter **siempre** genera `operation_id` (UUID v4) al crear la operación, sea para outbox o para REST directo. El backend verifica duplicado en `processed_operations` antes de procesar.
- Si el `operation_id` ya existe → devuelve `200` con `response_payload` original (sin reprocesar).

**Implementación sugerida:**
```java
// En un @ControllerAdvice o filtro común
@Component
public class IdempotencyInterceptor implements HandlerInterceptor {
    // Lee header "Idempotency-Key" o body.operation_id
    // Si existe, busca en processed_operations:
    //   - encontrado -> devuelve 200 + response_payload (short-circuit)
    //   - no encontrado -> continúa; al terminar guarda operation_id + response
}
```

**Endpoints afectados (escritura clínica):**
| Endpoint | Comando | operation_id obligatorio |
|---|---|---|
| `POST /patients` | `CREATE_PATIENT` | Sí (implementado como header `Idempotency-Key` **opcional** en el Commit 1) |
| `PUT /patients/{id}/contact` | `UPDATE_PATIENT_CONTACT` | Sí |
| `PUT /patients/{id}/identity` | `UPDATE_PATIENT_IDENTITY` | Sí |
| `POST /attentions` | `CREATE_ATTENTION` | Sí |
| `PUT /attentions/{id}` | `UPDATE_ATTENTION` | Sí |
| `POST /attentions/{id}/complete` | `COMPLETE_ATTENTION` | Sí |
| `POST /attentions/{id}/cancel` | `CANCEL_ATTENTION` | Sí |
| `POST /attentions/{id}/doses` | `REGISTER_APPLIED_DOSE` | Sí |
| `POST /attentions/{id}/doses/{doseId}/cancel` | `CANCEL_APPLIED_DOSE` | Sí |

---

### 1.4 Auditoría de operaciones clínicas

**Recomendación: tabla `audit_events` única para todo el sistema (incluye identidad, catálogo, clínico), con enum `action` y payload JSON.**

**Esquema:**
```sql
CREATE TABLE app.audit_events (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id              UUID NOT NULL REFERENCES app.users(id),
    institution_id        UUID NOT NULL REFERENCES app.institutions(id),
    action                TEXT NOT NULL,  -- enum: PATIENT_CREATED, ATTENTION_COMPLETED, DOSE_REGISTERED, DOSE_CANCELLED, etc.
    resource_type         TEXT NOT NULL,  -- enum: PATIENT, ATTENTION, APPLIED_DOSE, PATIENT_MERGE_REQUEST
    resource_id           UUID NOT NULL,
    client_operation_id   UUID,           -- operation_id del cliente (para trazabilidad sync)
    payload               JSONB NOT NULL, -- snapshot de lo relevante (antes/después, motivo cancelación, etc.)
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_actor ON app.audit_events (actor_id);
CREATE INDEX idx_audit_resource ON app.audit_events (resource_type, resource_id);
CREATE INDEX idx_audit_institution ON app.audit_events (institution_id);
CREATE INDEX idx_audit_created ON app.audit_events (created_at);
```

**Reglas:**
- Se escribe en **la misma transacción** que la operación de negocio (Spring `@Transactional`).
- `action` usa un enum tipado en Java (`AuditAction`) para evitar typos.
- `payload` incluye: para creación = DTO creado; para actualización = diff (antes/después); para cancelación = motivo + actor; para merge = ids involucrados.
- El `client_operation_id` permite correlacionar auditoría ↔ sync (outbox).

---

## 2. Esquema de base de datos (PostgreSQL)

### 2.1 Módulo `patients`
```sql
-- Tablas principales (V8)
CREATE TABLE app.patients ( ... ver 1.1 ... );
CREATE TABLE app.patient_contacts (patient_id UUID REFERENCES app.patients(id), type TEXT, value TEXT, is_primary BOOLEAN);
CREATE TABLE app.patient_demographics (patient_id UUID REFERENCES app.patients(id), gender TEXT, ethnicity TEXT, education_level TEXT);
CREATE TABLE app.patient_addresses (patient_id UUID REFERENCES app.patients(id), street TEXT, municipality_id UUID, department_id UUID, country_id UUID);
CREATE TABLE app.patient_guardians (patient_id UUID REFERENCES app.patients(id), relationship TEXT CHECK (relationship IN ('MOTHER','FATHER','CAREGIVER','OTHER')), full_name TEXT, document_type TEXT, document_number TEXT, phone TEXT);
CREATE TABLE app.patient_medical_histories (patient_id UUID REFERENCES app.patients(id), condition TEXT, diagnosed_at DATE, notes TEXT);
```

### 2.2 Módulo `attentions`
```sql
-- Tablas principales (V9)
CREATE TABLE app.attentions (
    id              UUID PRIMARY KEY,
    patient_id      UUID NOT NULL REFERENCES app.patients(id),
    professional_id UUID NOT NULL REFERENCES app.users(id),
    institution_id  UUID NOT NULL REFERENCES app.institutions(id),
    attention_date  TIMESTAMPTZ NOT NULL,
    consecutive     BIGINT,                    -- se asigna en servidor. Online-first: al crear (Pasos 1-3); con outbox: al sincronizarse (Paso 4)
    client_operation_id UUID,                  -- operation_id del CREATE_ATTENTION (trazabilidad, no PK de idempotencia: esa vive en processed_operations)
    status          TEXT NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','IN_PROGRESS','COMPLETED','CANCELLED')),
    observations    TEXT,
    version         BIGINT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_attention_operation UNIQUE (client_operation_id)
);

CREATE TABLE app.applied_doses ( ... ver 1.2 ... );
```

> `consecutive`: con la estrategia online-first (Pasos 1–3) se asigna al crear la
> atención en el servidor. Cuando llegue el outbox (Paso 4), el servidor lo
> asigna al aceptar el `CREATE_ATTENTION`, y el consecutivo local queda
> `NULL`/pendiente hasta ese momento.

### 2.3 Sincronización (a crear; NO existe aún)
```sql
-- processed_operations (para idempotencia de REST + sync, D3)
-- IMPORTANTE: NO existe todavia. V3 crea app.provisioning_operations (otra cosa:
-- aprovisionamiento de identidad). processed_operations es la tabla de
-- idempotencia de comandos clínicos/sync. Se crea en la migración de este módulo.
CREATE TABLE app.processed_operations (
    operation_id     UUID        PRIMARY KEY,            -- clave de idempotencia (única global)
    command_type     TEXT        NOT NULL,
    aggregate_id     UUID,
    response_payload JSONB       NOT NULL,               -- respuesta original (replay)
    sync_sequence    BIGSERIAL   NOT NULL,               -- cursor monotónico para pull (D3)
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_processed_operations_seq ON app.processed_operations (sync_sequence);

-- patient_merge_requests (para resolución de duplicados)
CREATE TABLE app.patient_merge_requests (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    duplicate_patient_id  UUID NOT NULL REFERENCES app.patients(id),
    canonical_patient_id  UUID REFERENCES app.patients(id),
    status                TEXT NOT NULL DEFAULT 'PENDING_REVIEW' CHECK (status IN ('PENDING_REVIEW','RESOLVED','REJECTED')),
    resolved_by           UUID REFERENCES app.users(id),
    resolved_at           TIMESTAMPTZ,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

> `provisioning_operations` (V3) y `processed_operations` (este módulo) son
> tablas distintas con propósitos distintos: la primera para idempotencia de
> creación de usuarios de identidad; la segunda para idempotencia de comandos
> clínicos y el cursor de sync. No deben confundirse.

---

## 3. Mapeo a SQLite (Flutter Drift)

Estado actual del esquema local (`app_database.dart`, `schemaVersion=4`):
- **Ya existen:** `CurrentUser`, `InstitutionsCache`, `UsersCache`, `SyncMetadata`, `VaccinesCache`, `VaccineOptionsCache`, `InstitutionVaccinesCache`, `InstitutionVaccineOptionsCache`.

**Decision de implementacion (online-first):** en el Paso 3 el flujo clinico
lee y escribe contra el backend; **no se agregan tablas clinicas a Drift
todavia**. Persistir pacientes/atenciones localmente sin el outbox (Paso 4)
dejaria datos locales sin sincronizar, por lo que se difiere hasta el SyncEngine
para no introducir estado inconsistente ni esquema muerto.

Tablas a agregar **cuando se implemente el SyncEngine (Paso 4)**:
- `patients`, `patient_contacts`, `patient_demographics`, `patient_addresses`, `patient_guardians`, `patient_medical_histories`
- `attentions`, `applied_doses`
- `sync_operations`, `sync_operation_dependencies` (outbox)
(dos bump de `schemaVersion`).

El catalogo efectivo para el formulario clinico se consume en vivo desde
`GET /catalogs/effective`; la cache de catalogo existente (Paso 4) cubre la
lectura offline futura.

---

## 4. Matriz de invariantes (tests espejo obligatorios)

| Caso | Dart (Flutter) | Java (Spring) |
|---|---|---|
| `cannot_edit_completed_attention` | Bloquea UI + no envía `UPDATE_ATTENTION` | Rechaza con 409/400 |
| `cannot_update_applied_dose` | No genera UPDATE; solo cancelar | Rechaza UPDATE/DELETE en `applied_doses` |
| `requires_reason_to_cancel_dose` | Valida campo motivo obligatorio | Rechaza si `cancelled_reason` vacío |
| `rejects_invalid_attention_transition` | Valida máquina de estados local | Valida transición en servicio |
| `does_not_auto_merge_patient_identity` | Marca candidato local, no mergea | Crea `PatientMergeRequest` |
| `rejects_operation_without_accepted_dependency` | Ordena cadena antes de push | Rechaza si dependencia no `ACCEPTED` |

---

## 5. Endpoints REST (resumen OpenAPI)

Ver `docs/api/openapi.yaml` (pendiente generar). Resumen clínico.

**Nota de permisos:** solo se usan los códigos **ya existentes** en la BD
(migraciones V1 y V5): `PATIENT_READ`, `PATIENT_WRITE`, `ATTENTION_READ`,
`ATTENTION_CREATE`, `MERGE_RESOLVE`, más los de catálogo (`CATALOG_GLOBAL_READ`,
`CATALOG_CONFIG_READ`). **No existe `ATTENTION_WRITE`**; si se necesita un
permiso de escritura de atención distinto a `ATTENTION_CREATE`, se agrega como
permiso nuevo (migración) y se asigna a los roles pertinentes, siguiendo el
patrón de V5. Por defecto se reutilizan los existentes:

- `VACCINATOR` (crea y completa): `PATIENT_WRITE`, `ATTENTION_CREATE`, `ATTENTION_READ`, `PATIENT_READ`.
- `ADMIN_INSTITUTION` (resuelve merges, lee): `PATIENT_READ`, `ATTENTION_READ`, `MERGE_RESOLVE`, `PATIENT_WRITE`.
- `READ_ONLY`: `PATIENT_READ`, `ATTENTION_READ`.

| Método | Ruta | Comando | Permiso | Scope |
|---|---|---|---|---|
| POST | `/patients` | `CREATE_PATIENT` | `PATIENT_WRITE` | Institución |
| GET | `/patients/{id}` | — | `PATIENT_READ` | Institución |
| PUT | `/patients/{id}/contact` | `UPDATE_PATIENT_CONTACT` | `PATIENT_WRITE` | Institución |
| PUT | `/patients/{id}/identity` | `UPDATE_PATIENT_IDENTITY` | `PATIENT_WRITE` | Institución (+ justificación) |
| GET | `/patients` | — | `PATIENT_READ` | Institución (busqueda por documento) |
| GET | `/attentions?patientId={id}` | — | `ATTENTION_READ` | Institución (historial del paciente; implementado en V9) |
| POST | `/attentions` | `CREATE_ATTENTION` | `ATTENTION_CREATE` | Institución |
| GET | `/attentions/{id}` | — | `ATTENTION_READ` | Institución |
| PUT | `/attentions/{id}` | `UPDATE_ATTENTION` | `ATTENTION_CREATE` | Institución (solo DRAFT/IN_PROGRESS) |
| POST | `/attentions/{id}/complete` | `COMPLETE_ATTENTION` | `ATTENTION_CREATE` | Institución |
| POST | `/attentions/{id}/cancel` | `CANCEL_ATTENTION` | `ATTENTION_CREATE` | Institución |
| POST | `/attentions/{id}/doses` | `REGISTER_APPLIED_DOSE` | `ATTENTION_CREATE` | Institución |
| POST | `/attentions/{id}/doses/{doseId}/cancel` | `CANCEL_APPLIED_DOSE` | `ATTENTION_CREATE` | Institución |

> Todos los endpoints se exponen bajo `/api/v1` y usan
> `@PreAuthorize("@authorization.hasPermission(authentication, '<PERMISO>')")`
> tal como en `CatalogController.java`. El `operation_id` viaja en el header
> `Idempotency-Key` (ver §1.3).

---

## 6. Próximos pasos

> Estado de implementación: **Commits 1 (V8, `patients`), 2 (V9, `attentions` +
> `applied_doses`) y 3 (Flutter + catalogo efectivo) implementados y verificados**
> (compilan, tests y arranque real contra Supabase con `ddl-auto=validate` OK).

1. **Paso 1 (V8)**: pacientes + `processed_operations` + `audit_events` + dominio `patients` Spring + tests. **Hecho.**
2. **Paso 2 (V9)**: atenciones + `applied_doses` + `patient_merge_requests` + dominio `attentions` + `AttentionService` + tests. **Hecho.**
3. **Paso 3 (Flutter)**: `GET /catalogs/effective` (backend) + features `patients`/`attentions` + pantallas "Nueva atención" e "Historial". **Hecho** (sin tablas Drift clínicas; ver §3).
4. **Paso 4**: SyncEngine + outbox (`sync_operations` en Drift) + push/pull + conflictos/merge.

> `audit_events` se crea en V8 (Paso 1) porque la auditoría clínica se escribe en
> la misma transacción que las primeras operaciones clínicas. `sync_operations`
> (outbox) es de Flutter/Drift y se agrega en el Paso 4.

### Notas de implementación (Commit 1)

- **Jackson 3**: Spring Boot 4 usa `tools.jackson.databind.ObjectMapper` (Jackson
  3) para sus beans; el `com.fasterxml.jackson` (Jackson 2) del `pom.xml` no
  expone un bean inyectable. `AuditService` y `ProcessedOperationsService`
  construyen su propio `ObjectMapper` de Jackson 3 (sin inyección) para evitar
  depender del bean.
- `POST /patients` acepta `Idempotency-Key` **opcional**; el soporte de
  idempotencia (`processed_operations`) queda listo para volverse obligatorio en
  la fase de sync.
- `GET /patients/{id}/attentions` se implementa en V9.

### Notas de implementación (Commit 2)

- Endpoints de atenciones en `/api/v1/attentions`; el historial del paciente es
  `GET /attentions?patientId={id}` (en lugar de `/patients/{id}/attentions`,
  para no cruzar modulos en el controller).
- Invariantes aplicadas en `AttentionService`: `COMPLETED` inmutable, atencion
  anulada no recibe dosis, `AppliedDose` append-only (sin UPDATE/DELETE; solo
  `cancel` con motivo). Las violaciones responden `409 INVALID_STATE`.
- Al registrar una dosis, el backend valida que la vacuna este habilitada en la
  institucion y que las opciones (dosis, neumococo y operativas) pertenezcan al
  contexto, y guarda el snapshot de texto + `catalog_version`.
- `POST /attentions` y `POST /attentions/{id}/doses` aceptan `Idempotency-Key`
  opcional.
- `consecutive` se asigna por institucion (`max + 1`) al crear la atencion;
  aproximacion sin bloqueo, suficiente para el MVP online-first.
- `GET /attentions?patientId=` cubre el "Historial" del dashboard.

### Notas de implementación (Commit 3 — Flutter)

- **Sin tablas Drift clinicas** en este paso: el flujo es online-first y
  persistir localmente sin outbox dejaria datos sin sincronizar (ver §3). El
  catalogo efectivo se lee en vivo de `GET /catalogs/effective`.
- Backend: `GET /api/v1/catalogs/effective` (`EffectiveCatalogService`) devuelve
  las vacunas habilitadas de la institucion con dosis, tipos de neumococo y
  opciones operativas en un solo DTO (alcance calculado en el servidor).
- Flutter: features `patients` (busqueda/creacion) y `attentions`
  (crear atencion, registrar dosis, completar, historial) + `AttentionController`
  que orquesta el flujo. Pantallas "Nueva atencion" e "Historial" conectadas a
  los destinos del dashboard (`ATTENTION_CREATE` / `ATTENTION_READ`).
- Online-first: las escrituras clinicas usan `OperationPermission.createPatient`
  / `createAttention` / `registerDose` / `completeAttention` con
  `offlineAuthorized: false` (requieren conexion hasta que exista el outbox).
- El formulario registra dosis con `vaccineId` + `doseOptionId` y, segun los
  flags de la vacuna, neumococo y opciones operativas (laboratorio, jeringa,
  gotero, observacion) + lote opcional.

### Catálogo geográfico (Bloque A — V10)

- Migración `V10__create_geo_catalog.sql`: `app.geo_countries`,
  `app.geo_departments`, `app.geo_municipalities` + FKs desde
  `app.patient_addresses` (columnas nullable).
- Seed idempotente `GeoCatalogImporter` desde
  `resources/catalog/divipola.json` (DIVIPOLA - DANE: 33 departamentos,
  1.122 municipios). País fijo: Colombia.
- Endpoints: `GET /api/v1/catalogs/geo/departments` y
  `GET /api/v1/catalogs/geo/municipalities?departmentId={id}` (permiso
  `CATALOG_GLOBAL_READ` o `CATALOG_CONFIG_READ`).
- Verificado contra Supabase: migración aplicada, seed 33/1.122, endpoints OK
  (Antioquia = 125 municipios; acentos correctos en la respuesta).
- Nota: el primer seed inserta ~1.155 filas por el pooler y puede tardar un par
  de minutos; es una operacion unica (idempotente por conteo).

### Wizard de registro de paciente (Bloque B)

- `PatientWizardPage` reemplaza el formulario de alta: 6 pasos (Identidad,
  Demografia, Contacto, Acompanante, Direccion, Antecedentes) y **un solo
  `POST /patients` al final**. Solo el paso 1 (identidad) es obligatorio.
- `NewPatientInput` (domain) transporta el perfil completo; el repositorio arma
  `demographics/contacts/addresses/guardians/medicalHistories` (omite bloques
  vacios).
- Direccion con departamento -> municipio dependientes, alimentados por
  `GET /catalogs/geo/departments` y `.../municipalities?departmentId=` (pais fijo
  Colombia).
- Verificado: `flutter analyze` sin issues y **120 tests** (incluye armado del
  body completo y endpoints geo).

### Ficha del paciente (Bloque C)

- **Backend**: `PUT /patients/{id}/demographics` (upsert) y
  `PUT /patients/{id}/medical-histories` (reemplaza la lista). Nuevos
  `AuditAction`: `PATIENT_DEMOGRAPHICS_UPDATED`, `PATIENT_HISTORY_UPDATED`.
  (Identidad y contacto/direccion ya existian.)
- **Flutter**: `PatientProfile` (perfil completo), `PatientDetailController` y
  `PatientDetailPage` con secciones y edicion (demografia, contacto/direccion,
  antecedentes). Acceso desde **Historial** con "Ver ficha del paciente".
- Verificado: backend 15 archivos de test sin fallos; `flutter analyze` sin
  issues; **126 tests** Flutter; arranque del backend OK.

### Aislamiento de sesión entre usuarios (Bloque D)

- **Problema**: los controladores se construyen una sola vez en `main.dart`, así
  que al cerrar sesión e ingresar con otra cuenta se arrastraba estado del
  usuario anterior (paciente seleccionado, atención en curso, catálogo efectivo,
  búsquedas, geografía, etc.).
- **Flutter**: se agrego `clearSession()` a `AdminController`, `UsersController`,
  `CatalogController`, `AttentionController`, `HistoryController` y
  `PatientDetailController` (estos dos ultimos renombrados desde `reset()` y
  `clear()`). `TuVacunaApp` hace seguimiento de `user.id` y limpia todos los
  controladores cuando cambia (logout o login con otra cuenta).
- **Catálogo efectivo**: `AttentionController.effectiveCatalogLoaded` distingue
  "cargando" de "sin vacunas habilitadas". `NuevaAtencionPage` muestra un spinner
  mientras carga y el reintento de error recarga el catálogo.
- Verificado: `flutter analyze` sin issues; **137 tests** Flutter.

---

**Estado:** Borrador para revisión.  
**Autor:** Arquitectura PAI.  
**Fecha:** 2026-09-07.