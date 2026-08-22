# PAI — Arquitectura del Sistema

> Documento de arquitectura base para la construcción de **Mi Vacuna / PAI** desde cero.
> Este es el plan de referencia: estructura de carpetas, entidades, relaciones, decisiones de diseño, seguridad, sesiones, roles y sincronización híbrida.
>
> **Estado: plan objetivo. Nada de lo descrito aquí está implementado todavía.**

---

## 1. Estado actual (punto de partida)

### 1.1 Lo que existe hoy (código en `lib/`)

La aplicación actual es un **Flutter local-first** con persistencia SQLite directa:

- SQLite almacena `nurses`, `patients`, `vaccines`, `vaccine_config_options` y `applied_doses`.
- No existe backend ni cliente HTTP.
- La autenticación se hace localmente contra SQLite con SHA-256 sin salt.
- La sesión vive solo en memoria y se pierde al reiniciar la app.
- GetX maneja estado, navegación y dependencias.
- Varios controladores y pantallas acceden directamente a `DatabaseHelper`.
- `sync_status` existe en dosis, pero no hay motor de sincronización real.

Defectos reales detectados en el código actual:

- `applied_dose_service.getDoseByUuid()` consulta la columna `uuid`, que no existe en el esquema.
- `applied_dose_service.markMultipleAsSynced()` interpola UUIDs en `IN (...)` sin parametrizar (SQL inválido para TEXT y riesgo de inyección).
- `patient_service` mezcla `int` y `String` para identificadores que en realidad son UUID.
- El modelo `Patient` actual mezcla paciente + atención + madre + cuidador en ~100 campos.
- `database_helper.dart` está en versión 1, sin `onUpgrade`; `applied_doses` se crea antes que `patients` aunque declara FK hacia ella.
- `PatientFormController` guarda paciente y dosis en operaciones separadas no transaccionales.
- Los README antiguos en la raíz (`DATABASE_README.md`, `MODELS_README.md`) describen un esquema viejo (`vaccination_records`, IDs `int`) que ya no existe.

**Decisión:** se reconstruye desde cero con arquitectura híbrida (backend + offline). No se parchea el código actual.

**Acción planificada (Fase 1):** marcar `DATABASE_README.md` y `MODELS_README.md` como legacy para que no contradigan este plan.

---
## 2. Arquitectura objetivo

```
                         +----------------------+
                         |      Flutter         |
                         |   Offline-first      |
                         +----------+-----------+
                                    | HTTPS
                                    v
                         +----------------------+
                         |     Spring Boot      |
                         |   Modular + Hexagonal|
                         +----------+-----------+
                                    | JDBC/JPA
                                    v
                         +----------------------+
                         | Supabase PostgreSQL  |
                         +----------------------+
```

Descripción técnica formal:

> Aplicación Flutter offline-first organizada con **Clean Architecture + Repository Pattern**, conectada a un **monolito modular Spring Boot** con **arquitectura hexagonal**, usando **PostgreSQL administrado por Supabase**, **Supabase Auth** para identidad, y **sincronización offline mediante Outbox Pattern con comandos de dominio e idempotencia por `operation_id`**.

### 2.1 Responsabilidades por componente

| Componente | Responsabilidad |
|---|---|
| Flutter UI | Capturar interacción del usuario |
| Flutter Use Cases | Coordinar acciones de la UI |
| Flutter Domain | Contratos y reglas del cliente |
| Flutter Repository | Decidir entre local y remoto |
| SQLite (Drift, cifrada) | Datos locales, caché y soporte offline |
| Outbox | Operaciones pendientes de sincronizar |
| Sync Engine | Procesar y sincronizar operaciones |
| Supabase Auth | Identidad y autenticación |
| Supabase PostgreSQL | Persistencia oficial (fuente de verdad) |
| Spring Controller | Capa HTTP |
| Spring Application | Casos de uso del negocio |
| Spring Domain | Reglas de negocio oficiales |
| Spring Infrastructure | Acceso a PostgreSQL (JPA/JDBC) |
| Audit | Trazabilidad de cambios |

---

## 3. Estructura de carpetas raíz (monorepo)

```text
pai/
│
├── apps/
│   └── mobile/                 # Flutter
│
├── services/
│   └── api/                    # Spring Boot
│
├── infra/
│   └── database/               # Migraciones SQL / esquemas
│
├── docs/
│   ├── architecture/
│   ├── domain/
│   ├── api/
│   ├── database/
│   └── synchronization/
│
├── .github/
│   └── workflows/
│
├── docker-compose.yml
├── README.md
└── .gitignore
```

**Decisiones sobre el monorepo:**

- Un solo repositorio con frontend y backend físicamente separados.
- No se crea `packages/api-contract` inicialmente: el contrato es **HTTP + JSON + OpenAPI** (`docs/api/openapi.yaml`).
- Dart y Java **no comparten entidades**; solo comparten el contrato de API.
- Se usa `infra/database/` y no `infra/supabase/`: PostgreSQL puede vivir en Docker local, Supabase, AWS o Railway sin cambiar la arquitectura.

---
## 4. Estructura Flutter (feature-first)

```text
apps/mobile/lib/
│
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── dependencies.dart
│
├── core/
│   ├── auth/
│   │   ├── session_manager.dart
│   │   ├── permission_service.dart
│   │   ├── offline_authorization_service.dart
│   │   └── auth_state.dart
│   ├── network/
│   │   ├── api_client.dart
│   │   ├── auth_interceptor.dart
│   │   └── network_info.dart
│   ├── storage/
│   │   ├── secure_storage.dart
│   │   └── database.dart          # Drift (cifrada)
│   ├── synchronization/
│   │   ├── sync_engine.dart
│   │   ├── sync_scheduler.dart
│   │   ├── sync_queue.dart
│   │   ├── sync_operation.dart
│   │   └── sync_status.dart
│   ├── connectivity/
│   ├── errors/
│   └── config/
│
├── shared/
│   ├── widgets/
│   ├── validators/
│   └── formatters/
│
└── features/
    ├── auth/
    ├── patients/
    ├── attentions/
    ├── vaccines/
    ├── catalogs/
    ├── users/
    └── reports/
```

### 4.1 Estructura de una feature Flutter

```text
features/attentions/
│
├── domain/
│   ├── entities/
│   │   ├── attention.dart
│   │   └── applied_dose.dart
│   ├── repositories/
│   │   └── attention_repository.dart
│   └── use_cases/
│       ├── register_attention.dart
│       ├── get_attention.dart
│       └── get_patient_attentions.dart
│
├── data/
│   ├── datasources/
│   │   ├── attention_local_datasource.dart
│   │   └── attention_remote_datasource.dart
│   ├── dtos/
│   ├── models/
│   ├── mappers/
│   ├── repositories/
│   │   └── attention_repository_impl.dart
│   └── sync/
│       └── attention_sync_handler.dart
│
└── presentation/
    ├── controllers/
    ├── pages/
    └── widgets/
```

### 4.2 Regla de oro del frontend

```
UI → Controller → Use Case → Repository → Local / Remote
```

Prohibido: Widget → SQLite, Controller → Dio, Widget → Supabase, Controller → SQL directo.

### 4.3 Reglas de dependencia

```
Domain no conoce Flutter, Drift, Dio, SQLite ni HTTP.
Data implementa los contratos definidos por Domain.
```

```dart
// domain/repositories
abstract class AttentionRepository {
  Future<Attention> register(RegisterAttentionCommand command);
}

// data/repositories
class AttentionRepositoryImpl implements AttentionRepository {
  // SQLite + API + sincronización
}
```

---

## 5. Estructura Spring Boot (monolito modular + hexagonal)

```text
services/api/src/main/java/com/pai/api/
│
├── shared/
│   ├── security/
│   ├── exceptions/
│   ├── pagination/
│   └── auditing/
│
├── identity/          # institutions, app.users, roles, permissions
├── patients/
├── attentions/
├── catalogs/          # vaccines, config_options, insurers, laboratories, geo
├── synchronization/   # push, pull, processed_operations, conflicts
├── audit/
└── reports/
```

Cada módulo sigue la estructura: `domain/` (model, repository, service) + `application/` (command, usecase, mapper) + `infrastructure/` (persistence) + `presentation/` (controller, request, response).

### 5.1 Reglas de dependencia en Spring

```
Domain no sabe que existe Hibernate, JPA, PostgreSQL ni Supabase.
Infrastructure implementa las interfaces del Domain.
```

---
## 6. Entidades y relaciones

### 6.1 Modelo conceptual

```
Institution 1 ──── N User
User N ──────── N Role            (via user_roles)
Role 1 ──────── N Permission      (via role_permissions)

Patient 1 ──── N Attention ──── professional → User
                          └─── institution → Institution
Attention 1 ──── N AppliedDose ──── vaccine → Vaccine (catálogo global)

Vaccine 1 ──── N VaccineSchedule
Vaccine 1 ──── N VaccineConfigOption

Patient ── ContactData (VO), DemographicData (VO) ── Address (VO)
Patient 1 ── 0..2 Guardian (relationship: MOTHER | FATHER | CAREGIVER | OTHER)
Patient 1 ── N MedicalHistory
Patient N ── 1 HealthInsurer

AuditEvent ──── actor → User (+ institution, action enum, timestamp, payload)
```

### 6.2 Entidades por módulo

#### identity

| Entidad | Campos clave |
|---|---|
| `auth.users` | id (UUID), email, encrypted_password, confirmed_at — **gestionado por Supabase Auth** |
| `app.users` | id (= auth.users.id), institution_id, document_type, document_number, first_name, last_name, status, created_at, updated_at |
| `Institution` | id, code, name, status, created_at, updated_at |
| `Role` | id, code, name, description |
| `Permission` | id, code, name |
| `UserRole` | user_id, role_id |
| `RolePermission` | role_id, permission_id |
| `SyncScope` | user_id, institution_id, geographic_scope (department/municipality), assigned_population, effective_from/to |

#### patients

| Entidad | Campos clave |
|---|---|
| `Patient` | id, id_type, id_number, nombres, birth_date, **sex (biológico)**, demografía (gender en VO), residencia, contactos, antecedentes, insurer_id, status (soft delete), **version**, created_at, updated_at |

`Patient.sex` se usa para reglas clínicas; `DemographicData.gender` es dato demográfico. Son conceptos distintos.

#### attentions

| Entidad | Campos clave |
|---|---|
| `Attention` | id, patient_id, professional_id, institution_id, attention_date, consecutive (nullable hasta sync), client_operation_id, status, observations, **version**, created_at, updated_at |
| `AppliedDose` | id, attention_id, vaccine_id, schedule_id, application_date, lot_number, **vaccine_name_snapshot, dose_label_snapshot, catalog_version**, selected_*, next_dose_date, status |

#### catalogs (globales, no por institución)

| Entidad | Campos clave |
|---|---|
| `Vaccine` | id, name, code, category, max_doses, min_months, max_months, flags de configuración, is_active, **version** |
| `VaccineSchedule` | id, vaccine_id, dose_number, min_months, max_months, interval_from_previous_dose, is_active, **version** |
| `VaccineConfigOption` | id, vaccine_id, field_type, value, display_name, sort_order, is_default, is_active, **version** |
| `HealthInsurer` | id, code, name, is_active, **version** |
| `Laboratory` | id, code, name, is_active, **version** |
| `GeoCountry/Department/Municipality` | id, code, name, parent_id |

Opcional para configuración local: `InstitutionVaccineConfig` (activar/desactivar disponibilidad por institución). No es necesaria en el MVP si el catálogo es 100 % global.

#### synchronization / audit

| Entidad | Campos clave |
|---|---|
| `SyncOperation` (cliente) | id, operation_id, command_type, aggregate_id, payload, status, retry_count, next_retry_at, last_error, created_at |
| `SyncOperationDependency` (cliente) | operation_id, depends_on_operation_id |
| `ProcessedOperation` (servidor) | operation_id (PK), response_payload, created_at — retención larga |
| `PatientMergeRequest` | id, duplicate_patient_id, canonical_patient_id, status (PENDING_REVIEW), resolved_by, resolved_at |
| `AuditEvent` | id, actor_id, institution_id, action (enum), resource_type (enum), resource_id, client_operation_id, payload, created_at |

### 6.3 Reglas de agregado

- `Attention` es **agregado raíz**; referencia a `Patient` solo por `patientId`.
- `AppliedDose` vive **dentro** del agregado `Attention`; no tiene CRUD independiente.
- `Attention` es **mutable solo en `DRAFT` / `IN_PROGRESS`**; al pasar a `COMPLETED` queda bloqueada (solo se anula con motivo).
- `AppliedDose` es **append-only**: `REGISTERED → CANCELLED(reason, actor, timestamp)`. Nunca UPDATE/DELETE.
- Los catálogos son **referencia + caché**; nunca se modifican desde operaciones offline.

---
## 7. Roles, permisos y política offline

### 7.1 Roles definitivos

| Rol | Offline | Función principal |
|---|---|---|
| `SUPER_ADMIN` | No (100 % online) | Administración global, sin scope de institución |
| `ADMIN_INSTITUTION` | No (100 % online) | Configuración local de su institución, usuarios, resolución de conflictos |
| `VACCINATOR` | Sí (offline-first) | Registrar pacientes, atenciones y dosis |
| `READ_ONLY` | Réplica local de solo lectura | Consultar información dentro de su scope |

**No existe `ADMIN_HOSPITAL`.** Los catálogos son **globales (nacionales)**: solo `SUPER_ADMIN` los escribe; ningún otro rol los modifica.

### 7.2 Permisos por rol (ejemplo)

```text
SUPER_ADMIN:        todos, alcance global (incluye CATALOG_WRITE, INSTITUTION_WRITE)
ADMIN_INSTITUTION:  PATIENT_READ/WRITE, CATALOG_READ, INVENTORY_READ/WRITE,
                    USER_READ/USER_MANAGE (solo su institución),
                    ATTENTION_READ, MERGE_RESOLVE (scope: su institución)
VACCINATOR:         PATIENT_READ/WRITE, ATTENTION_CREATE/READ, CATALOG_READ
READ_ONLY:          PATIENT_READ, ATTENTION_READ, CATALOG_READ
```

### 7.3 Política offline por rol

| Rol | Capacidades offline |
|---|---|
| `VACCINATOR` | `CAN_READ_LOCAL`, `CAN_CREATE_PATIENT`, `CAN_CREATE_ATTENTION`, `CAN_REGISTER_DOSE`, `CAN_QUEUE_SYNC` |
| `ADMIN_*` / `SUPER_ADMIN` | Ninguna escritura; trabajan 100 % online |
| `READ_ONLY` | `CAN_READ_LOCAL` únicamente |

**Idea central:** el offline no pertenece al usuario; pertenece a las **operaciones que ese usuario puede ejecutar**.

### 7.4 Implementación

```dart
enum OfflinePolicy {
  fullOfflineWrite,  // VACCINATOR: SQLite + outbox
  readOnly,          // READ_ONLY
  none,              // ADMIN_INSTITUTION, SUPER_ADMIN
}
```

El rol determina qué operaciones están permitidas; la arquitectura determina cómo se ejecutan. Se evita llenar el código de `if (role == ...)`.

---
## 8. Sesión y política de autorización offline

### 8.1 Almacenamiento

```text
flutter_secure_storage (secretos):
  access_token, refresh_token, session_expires_at, last_online_validation

SQLite (no secreto):
  current_user, institution, roles, permissions, sync_cursor, last_catalog_sync
```

El JWT nunca se guarda en SQLite. La contraseña y su hash nunca viven en Flutter.

### 8.2 Política de autorización offline (ventana configurable)

No es un token especial: es una **política basada en timestamp**.

```text
last_online_validation     (persistido al validar sesión online)
offline_window_hours       (default: 7 días, configurable por institución)

Mientras ahora - last_online_validation <= window:
    → operación offline permitida (según rol)
Después:
    → OFFLINE_LOCKED: solo lectura, no nuevas operaciones
```

### 8.3 Mitigaciones obligatorias (por la ventana larga de 7 días)

1. **Bloqueo local obligatorio**: PIN o biometría para abrir la app.
2. **DB local cifrada** (SQLCipher/Drift, clave en secure storage).
3. **Rechazo en servidor**: si el usuario fue desactivado, sus operaciones pendientes pasan a `QUARANTINED` (no se borran; se revisan).
4. **Auditoría completa** de todo lo registrado dentro de la ventana.
5. **Configurable por institución**: 7 días es el default; una institución puede endurecerlo sin cambiar código.
6. **Purga al cambiar de institución o scope**: invalida los datos locales.

### 8.4 Al reconectar

1. Refresh / validar sesión.
2. Verificar usuario activo, institución y permisos.
3. Si sigue autorizado → desbloquear y sincronizar.
4. Si fue desactivado o perdió permisos → bloquear operaciones; datos sensibles se purgan según política.

---
## 9. Autenticación y usuarios

### 9.1 Identidad

| Tabla | Origen | Quién escribe |
|---|---|---|
| `auth.users` | Supabase Auth | Supabase (solo lectura desde Spring) |
| `app.users` | Spring Boot | Spring (como mirror de `auth.users` + atributos de negocio) |

**Regla:** `app.users.id = auth.users.id`. Spring **nunca crea** usuarios en `auth.users`; eso lo hace Supabase Auth directamente (signup, invitación).

### 9.2 Flujo de registro/login

```text
1. Registro/invitación en Supabase Auth → auth.users creado
2. Spring sincroniza → app.users con institution_id, roles, permissions
3. Login: Supabase Auth → JWT (sub = auth.users.id)
4. Spring valida JWT → resuelve institutionId, professionalId, roles
5. Spring NUNCA confía en el body del request para institutionId
```

### 9.3 JWT claims (custom claims)

```json
{
  "sub": "uuid-del-usuario",
  "email": "user@example.com",
  "institution_id": "uuid-de-la-institucion",
  "roles": ["VACCINATOR"],
  "permissions": ["PATIENT_READ", "PATIENT_WRITE", "ATTENTION_CREATE", "CATALOG_READ"],
  "exp": 1234567890
}
```

Los claims `institution_id`, `roles` y `permissions` se sincronizan desde `app.users` al momento de login.

---
## 10. Seguridad en Spring Boot

### 10.1 Autenticación

```text
Supabase Auth → JWT con claims customizados
Spring Security → Resource Server (validación de JWT)
Supabase Management API → NO se usa (excepto invitaciones)
```

### 10.2 Autorización

```text
@PreAuthorize("@security.hasPermission('ATTENTION_CREATE')")
public ResponseEntity<AttentionResponse> create(@RequestBody @Valid AttentionRequest request) {
    // El controller recibe el request
    // El use case ejecuta la lógica
    // Spring Security inyecta el usuario autenticado
}
```

### 10.3 Extraer usuario del JWT

```java
@Component
public class SecurityUtils {
    public UUID getCurrentUserId(Authentication auth) {
        Jwt jwt = (Jwt) auth.getPrincipal();
        return UUID.fromString(jwt.getSubject());
    }

    public UUID getCurrentInstitutionId(Authentication auth) {
        Jwt jwt = (Jwt) auth.getPrincipal();
        return UUID.fromString((String) jwt.getClaim("institution_id"));
    }

    public List<String> getCurrentRoles(Authentication auth) {
        Jwt jwt = (Jwt) auth.getPrincipal();
        return jwt.getClaimAsStringList("roles");
    }

    public List<String> getCurrentPermissions(Authentication auth) {
        Jwt jwt = (Jwt) auth.getPrincipal();
        return jwt.getClaimAsStringList("permissions");
    }
}
```

### 10.4 Auditoría

```java
@EntityListeners(AuditEntityListener.class)
public class BaseEntity {
    @CreatedDate
    private Instant createdAt;

    @LastModifiedDate
    private Instant updatedAt;

    @CreatedBy
    private UUID createdBy;

    @LastModifiedBy
    private UUID updatedBy;
}
```

### 10.5 Reglas de seguridad

| Regla | Detalle |
|---|---|
| JWT expiration | 15 min access + refresh token |
| Refresh token rotation | Cada refresh genera nuevo token |
| Revoke al logout | Server-side revoke |
| Rate limiting | Endpoints públicos: 100 req/min |
| HTTPS | Forzado en todos los endpoints |
| CORS | Solo dominios autorizados |
| SQL Injection | Parameters only (JPA/JDBC) |
| XSS | HTML encoding + Content-Security-Policy |
| CSRF | Token-based para formularios |
| Password policy | Mínimo 8 caracteres, mayúscula, minúscula, número |
| Account lockout | 5 intentos fallidos → 15 min lock |
| Session timeout | 30 min inactividad |
| Audit trail | Todas las operaciones sensibles |

---
## 11. Sincronización

### 11.1 Flujo general

```text
Flutter (offline)
  → SQLite + Outbox (operación local con operation_id)
  → SyncEngine procesa la cola

Flutter → SyncService → SyncRepository
  └── Pregunta: ¿está online?
        → Sí: Push + Pull
        → No: Continúa con SQLite local

Push: POST /api/sync/push
  └── Server valida, aplica, guarda operation_id en processed_operations

Pull: GET /api/sync/pull?since={cursor}
  └── Server devuelve operaciones del scope que el usuario no ha visto
```

### 11.2 Outbox Pattern ( cliente)

```text
sync_operations:
  - id               (PK local)
  - operation_id     (UUID, idempotency key)
  - command_type     (CREATE_PATIENT, REGISTER_APPLIED_DOSE, etc.)
  - aggregate_id     (UUID del agregado afectado)
  - payload          (JSON del comando)
  - status           (PENDING | PROCESSING | COMPLETED | FAILED | QUARANTINED)
  - retry_count      (int)
  - next_retry_at    (timestamp)
  - last_error       (texto)
  - created_at       (timestamp)
```

### 11.3 Grafo de dependencias

```text
sync_operation_dependencies:
  - operation_id         (FK → sync_operations.operation_id)
  - depends_on_operation_id (FK → sync_operations.operation_id)

Validación antes de push:
  1. Todos los operaciones en la cadena deben estar COMPLETED o PENDING
  2. Si alguno falla → la cadena entera se bloquea
  3. El servidor procesa en orden topológico
```

### 11.4 Comandos de dominio (D1)

| Comando | Descripción | Atomicidad |
|---|---|---|
| `CREATE_PATIENT` | Crear paciente | Atomic |
| `UPDATE_PATIENT_CONTACT` | Actualizar contactos (teléfono, email, dirección) | Atomic |
| `UPDATE_PATIENT_IDENTITY` | Actualizar identidad (nombres, fecha nacimiento) — requiere justificación | Atomic |
| `CREATE_ATTENTION` | Crear atención vacía (DRAFT) | Atomic |
| `UPDATE_ATTENTION` | Modificar atención (solo DRAFT/IN_PROGRESS) | Atomic |
| `REGISTER_APPLIED_DOSE` | Registrar dosis aplicada (append-only) | Atomic |
| `COMPLETE_ATTENTION` | Cambiar estado de atención a COMPLETED (bloquea edición) | Atomic |
| `CANCEL_APPLIED_DOSE` | Anular dosis con motivo (append-only) | Atomic |
| `CANCEL_ATTENTION` | Anular atención con motivo | Atomic |

### 11.5 Idempotencia (D3)

```text
Cada comando incluye:
  - operation_id: UUID generado por el cliente (único globalmente)
  - El servidor guarda en processed_operations:
    { operation_id, response_payload, created_at }

Al recibir un push con operation_id duplicado:
  → Retorna 200 + response_payload original (no reprocesa)
```

### 11.6 Push (cliente → servidor)

```text
POST /api/sync/push

Body:
{
  "operations": [
    {
      "operation_id": "uuid-1",
      "command_type": "REGISTER_APPLIED_DOSE",
      "aggregate_id": "uuid-paciente",
      "payload": { ... },
      "dependencies": ["uuid-0"]  // opcional
    }
  ]
}

Response 200:
{
  "accepted": ["uuid-1", "uuid-2"],
  "rejected": [
    {
      "operation_id": "uuid-3",
      "reason": "DEPENDENCY_FAILED",
      "error": "Dependencia uuid-2 falló"
    }
  ]
}
```

### 11.7 Pull (servidor → cliente)

```text
GET /api/sync/pull?since={cursor}&scope={institution_id,municipality_id}

Response 200:
{
  "operations": [
    {
      "operation_id": "uuid-server-1",
      "command_type": "CATALOG_UPDATE",
      "aggregate_id": "uuid-vaccine",
      "payload": { ... },
      "timestamp": "2026-08-22T10:00:00Z"
    }
  ],
  "next_cursor": "uuid-server-10"
}
```

### 11.8 Sync Scope (D9)

```text
sync_scopes:
  - user_id
  - institution_id
  - geographic_scope (department_id, municipality_id)
  - assigned_population (opcional: lista de pacientes asignados)
  - effective_from
  - effective_to

Cada pull filtra por el scope del usuario:
  - Si scope = institución → solo datos de esa institución
  - Si scope = municipio → datos de todos los usuarios en ese municipio
  - Si scope = departamento → datos de todos los municipios del departamento
```

### 11.9 Catálogos globales (D7)

```text
Los catálogos (Vaccine, VaccineSchedule, VaccineConfigOption, HealthInsurer, Laboratory, Geo*)
son GLOBALES: no están filtrados por institución.

Pull de catálogos:
  - Se descargan completos la primera vez
  - Después, solo se descargan cambios (por version)
  - Las AppliedDose almacenan snapshot:
    { vaccine_name_snapshot, dose_label_snapshot, catalog_version }
```

### 11.10 Resolución de conflictos (D6)

#### Conflictos de identidad de paciente

```text
Si un paciente ya existe (por document_type + document_number) pero el cliente
tiene un paciente diferente con el mismo documento:

  → Return: DUPLICATE_BUSINESS_IDENTITY
  → El servidor crea un PatientMergeRequest
  → Resuelto por ADMIN_INSTITUTION (online)

Reglas:
  1. Se preservan ambos historiales de atención
  2. Se consolidan los datos de contacto
  3. La identidad canonical es decidida por el admin
```

#### Conflictos de sincronización

```text
Cuando dos clientes modifican el mismo registro:

  - Patient (contact fields): sync merge con trazabilidad
  - Patient (identity fields): SERVER WINS + reason
  - Attention: SERVER WINS (si ya está COMPLETED)
  - AppliedDose: append-only, no hay conflicto
  - Catalogs: no se modifican desde offline
```

### 11.11 Offline window de autorización (D10)

```text
Vigilancia de sesión offline:

  1. Al login online: guardar last_online_validation timestamp
  2. Offline: validar que last_online_validation <= 7 días
  3. Si > 7 días: OFFLINE_LOCKED (solo lectura, no nuevas operaciones)
  4. Al reconectar: refresh token, validar usuario, desbloquear o purgar

Configuración por institución:
  - offline_window_hours: default 7 días (puede ajustarse por institución)
  - configurable en tabla de configuración de institución
```

---
## 12. Decisiones de diseño (D1-D11)

| # | Decisión | Descripción | Estado |
|---|---|---|---|
| D1 | Comandos de dominio | Sync por comandos (no comando gigante), atomicos | Confirmada |
| D2 | IDs | UUID cliente + documento (negocio) + consecutivo (nullable) | Confirmada |
| D3 | Idempotencia | `operation_id` + `processed_operations` (retención larga) | Confirmada |
| D4 | Append-only doses | `AppliedDose`: `REGISTERED → CANCELLED(reason, actor, timestamp)` | Confirmada |
| D5 | Versionado selectivo | `version` en Patient, Attention (DRAFT/IN_PROGRESS) y catálogos | Corregida |
| D6 | Duplicidad por regla | Detección automática → `REQUIRES_REVIEW` → resolución por admin | Confirmada |
| D7 | Catálogo global + snapshot | Catálogo global + snapshot histórico en AppliedDose | Ampliada |
| D8 | READ_ONLY | Réplica local de solo lectura | Confirmada |
| D9 | Sync Scope | Sync por institución + municipio | Definida |
| D10 | Offline window | 7 días default + mitigaciones obligatorias | Definida |
| D11 | Fuente de verdad | Matriz por tipo de dato (identidad, contacto, append-only, etc.) | Confirmada |

### 12.1 Matriz de escenarios de conflicto

| Escenario | Resolución | Auditoría |
|---|---|---|
| Paciente creado por 2 dispositivos | Detección por regla de negocio → `REQUIRES_REVIEW` → `PatientMergeRequest` | Sí |
| Paciente modificado por 2 dispositivos | Merge de contacto / SERVER WINS identidad | Sí |
| Atención modificada después de COMPLETED | Rechazo | Sí |
| Dosis modificada después de REGISTERED | Append-only (CANCELLED) | Sí |
| Catálogo modificado desde offline | Rechazo (solo `SUPER_ADMIN` modifica catálogos globales) | Sí |
| Token expirado | Re-login obligatorio | No |
| Offline > 7 días | OFFLINE_LOCKED (solo lectura) | Sí |
| Usuario desactivado mientras offline | Operaciones QUARANTINED al reconectar | Sí |
| Cambio de institución | Purga de datos locales + re-scope | Sí |

---
## 13. Contrato API (OpenAPI)

El contrato completo se documenta en `docs/api/openapi.yaml`. Resumen de endpoints principales:

### 13.1 Autenticación

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/auth/login` | Login con email/password → JWT |
| POST | `/auth/refresh` | Refresh token → nuevo JWT |
| POST | `/auth/logout` | Revocar token |

### 13.2 Instituciones (SUPER_ADMIN)

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/institutions` | Crear institución (SUPER_ADMIN) |
| GET | `/institutions` | Listar instituciones |
| GET | `/institutions/{id}` | Obtener institución |
| PUT | `/institutions/{id}` | Modificar institución (SUPER_ADMIN) |
| PUT | `/institutions/{id}/status` | Activar/desactivar institución (SUPER_ADMIN) |
| PUT | `/institutions/{id}/config` | Configuración local (incluye `offline_window_hours`) (SUPER_ADMIN) |

### 13.3 Pacientes

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/patients` | Crear paciente |
| GET | `/patients/{id}` | Obtener paciente |
| PUT | `/patients/{id}/contact` | Actualizar contactos |
| PUT | `/patients/{id}/identity` | Actualizar identidad (requiere justificación) |
| GET | `/patients` | Listar pacientes (con filtros) |
| GET | `/patients/{id}/attentions` | Atenciones de un paciente |
| POST | `/patients/{id}/merge` | Solicitar merge de duplicados |

### 13.4 Atenciones

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/attentions` | Crear atención (DRAFT) |
| GET | `/attentions/{id}` | Obtener atención |
| PUT | `/attentions/{id}` | Modificar atención (solo DRAFT/IN_PROGRESS) |
| POST | `/attentions/{id}/complete` | Completar atención (bloquea edición) |
| POST | `/attentions/{id}/cancel` | Anular atención con motivo |
| POST | `/attentions/{id}/doses` | Registrar dosis (append-only) |
| POST | `/attentions/{id}/doses/{doseId}/cancel` | Anular dosis con motivo |

### 13.5 Catálogos

Los endpoints de lectura son públicos para usuarios autenticados. Los de escritura requieren `SUPER_ADMIN` (catálogos globales).

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/catalogs/vaccines` | Listar vacunas |
| GET | `/catalogs/vaccines/{id}/schedules` | Programación de dosis |
| GET | `/catalogs/vaccines/{id}/config` | Configuración de vacuna |
| GET | `/catalogs/insurers` | Listar aseguradoras |
| GET | `/catalogs/laboratories` | Listar laboratorios |
| GET | `/catalogs/geo/departments` | Listar departamentos |
| GET | `/catalogs/geo/municipalities?departmentId={id}` | Listar municipios |
| POST | `/catalogs/vaccines` | Crear vacuna (SUPER_ADMIN) |
| PUT | `/catalogs/vaccines/{id}` | Modificar vacuna (SUPER_ADMIN) |
| POST | `/catalogs/vaccines/{id}/schedules` | Crear programación (SUPER_ADMIN) |
| PUT | `/catalogs/vaccines/{id}/schedules/{scheduleId}` | Modificar programación (SUPER_ADMIN) |
| POST | `/catalogs/vaccines/{id}/config` | Crear opción de configuración (SUPER_ADMIN) |
| PUT | `/catalogs/vaccines/{id}/config/{configId}` | Modificar opción (SUPER_ADMIN) |
| POST | `/catalogs/insurers` | Crear aseguradora (SUPER_ADMIN) |
| PUT | `/catalogs/insurers/{id}` | Modificar aseguradora (SUPER_ADMIN) |
| POST | `/catalogs/laboratories` | Crear laboratorio (SUPER_ADMIN) |
| PUT | `/catalogs/laboratories/{id}` | Modificar laboratorio (SUPER_ADMIN) |

### 13.6 Sincronización

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/sync/push` | Enviar operaciones pendientes |
| GET | `/sync/pull?since={cursor}&scope={scope}` | Recibir operaciones del servidor |

### 13.7 Conflictos

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/conflicts` | Listar conflictos pendientes |
| PUT | `/conflicts/{id}/resolve` | Resolver conflicto |
| GET | `/conflicts/{id}/details` | Detalles de conflicto |

### 13.8 Usuarios (ADMIN_INSTITUTION)

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/users` | Crear usuario (invitación) |
| GET | `/users` | Listar usuarios de la institución |
| PUT | `/users/{id}` | Modificar usuario |
| PUT | `/users/{id}/status` | Activar/desactivar usuario |
| GET | `/users/{id}/roles` | Obtener roles de usuario |
| PUT | `/users/{id}/roles` | Asignar roles |

### 13.9 Auditoría

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/audit/events` | Listar eventos de auditoría |
| GET | `/audit/events/{id}` | Detalle de evento |

---
## 14. Esquema de base de datos

### 14.1 PostgreSQL (Supabase)

El esquema completo se documenta en `docs/database/postgres-schema.sql`. Resumen de tablas principales:

**Módulo identity:**
- `auth.users` (Supabase Auth)
- `app.users`
- `institutions`
- `roles`
- `permissions`
- `user_roles`
- `role_permissions`
- `sync_scopes`

**Módulo patients:**
- `patients`
- `patient_contacts`
- `patient_demographics`
- `patient_addresses`
- `patient_medical_histories`
- `patient_guardians`

**Módulo attentions:**
- `attentions`
- `applied_doses`

**Módulo catalogs:**
- `vaccines`
- `vaccine_schedules`
- `vaccine_config_options`
- `health_insurers`
- `laboratories`
- `geo_countries`
- `geo_departments`
- `geo_municipalities`

**Módulo synchronization:**
- `processed_operations`
- `patient_merge_requests`

**Módulo audit:**
- `audit_events`

### 14.2 SQLite (Flutter offline)

El esquema completo se documenta en `docs/database/sqlite-schema.drift`. Resumen de tablas principales:

**Módulo identity (caché):**
- `users_cache`
- `institutions_cache`
- `roles_cache`
- `permissions_cache`

**Módulo patients:**
- `patients`
- `patient_contacts`
- `patient_demographics`
- `patient_addresses`
- `patient_medical_histories`
- `patient_guardians`

**Módulo attentions:**
- `attentions`
- `applied_doses`

**Módulo catalogs (caché):**
- `vaccines_cache`
- `vaccine_schedules_cache`
- `vaccine_config_options_cache`
- `health_insurers_cache`
- `laboratories_cache`
- `geo_cache`

**Módulo synchronization:**
- `sync_operations`
- `sync_operation_dependencies`

### 14.3 Mapeo de tipos

| PostgreSQL | SQLite (Drift) | Dart |
|---|---|---|
| `UUID` | `TEXT` | `String` |
| `TIMESTAMPTZ` | `INTEGER` (epoch) | `DateTime` |
| `TEXT` | `TEXT` | `String` |
| `INTEGER` | `INTEGER` | `int` |
| `BOOLEAN` | `INTEGER` (0/1) | `bool` |
| `JSONB` | `TEXT` | `String` (JSON serializado) |
| `ENUM` | `TEXT` | `String` (validado en dominio) |

---
## 15. Plan de fases de implementación

### Fase 1: Fundamentos (Semanas 1-2)

**Objetivo:** Proyecto andando, arquitectura base, primer CRUD completo end-to-end.

| # | Tarea | Dependencias |
|---|---|---|
| 1.1 | Inicializar monorepo (estructura de carpetas) | Ninguna |
| 1.2 | Configurar Spring Boot (modular, hexagonal) | 1.1 |
| 1.3 | Configurar Flutter (feature-first, Clean Architecture) | 1.1 |
| 1.4 | Configurar Supabase (auth, database, RLS) | 1.2 |
| 1.5 | Crear esquema PostgreSQL (módulo identity) | 1.4 |
| 1.6 | Crear esquema SQLite (módulo identity) | 1.3 |
| 1.7 | Implementar auth en Spring (JWT, Resource Server) | 1.5 |
| 1.8 | Implementar auth en Flutter (login, session) | 1.6, 1.7 |
| 1.9 | CRUD de institutions (Spring + Flutter) | 1.8 |
| 1.10 | CRUD de users (Spring + Flutter) | 1.9 |
| 1.11 | Marcar `DATABASE_README.md` y `MODELS_README.md` como legacy | 1.1 |

**Entregable:** Login funcional, CRUD de usuarios, estructura de proyecto completa.

### Fase 2: Dominio core (Semanas 3-4)

**Objetivo:** Pacientes y atenciones con sync básica.

| # | Tarea | Dependencias |
|---|---|---|
| 2.1 | Esquema PostgreSQL (módulo patients) | 1.5 |
| 2.2 | Esquema SQLite (módulo patients) | 1.6 |
| 2.3 | Dominio Patient (Spring) | 2.1 |
| 2.4 | Dominio Patient (Flutter) | 2.2 |
| 2.5 | CRUD de patients (Spring + Flutter) | 2.3, 2.4 |
| 2.6 | Esquema PostgreSQL (módulo attentions) | 2.1 |
| 2.7 | Esquema SQLite (módulo attentions) | 2.2 |
| 2.8 | Dominio Attention (Spring) | 2.6 |
| 2.9 | Dominio Attention (Flutter) | 2.7 |
| 2.10 | CRUD de attentions (Spring + Flutter) | 2.8, 2.9 |

**Entregable:** CRUD de pacientes y atenciones completo.

### Fase 3: Sincronización (Semanas 5-6)

**Objetivo:** Sync completa con outbox, dependencias, idempotencia.

| # | Tarea | Dependencias |
|---|---|---|
| 3.1 | Esquema SQLite (sync_operations, dependencies) | 2.7 |
| 3.2 | Esquema PostgreSQL (processed_operations) | 2.6 |
| 3.3 | SyncEngine (Flutter) | 3.1 |
| 3.4 | SyncController (Spring) | 3.2 |
| 3.5 | Push (Flutter → Spring) | 3.3, 3.4 |
| 3.6 | Pull (Spring → Flutter) | 3.3, 3.4 |
| 3.7 | Idempotencia (server-side) | 3.4 |
| 3.8 | Grafo de dependencias (server-side) | 3.7 |
| 3.9 | Conflictos de negocio (server-side) | 3.8 |
| 3.10 | Offline window (Flutter) | 3.3 |

**Entregable:** Sync completa con manejo de conflictos y offline window.

### Fase 4: Catálogos y dosis (Semanas 7-8)

**Objetivo:** Catálogos globales, AppliedDose append-only, snapshot.

| # | Tarea | Dependencias |
|---|---|---|
| 4.1 | Esquema PostgreSQL (catálogos) | 1.5 |
| 4.2 | Esquema SQLite (caché de catálogos) | 1.6 |
| 4.3 | Dominio Vaccine, VaccineSchedule, VaccineConfigOption | 4.1 |
| 4.4 | Sync de catálogos (global, versionado) | 4.2, 3.6 |
| 4.5 | AppliedDose (append-only) | 2.8 |
| 4.6 | Snapshot de catálogo en AppliedDose | 4.4, 4.5 |
| 4.7 | Detección de duplicados (regla de negocio) | 4.3 |
| 4.8 | PatientMergeRequest | 4.7 |
| 4.9 | Documento `docs/database/postgres-schema.sql` (esquema completo) | 2.6, 4.1 |
| 4.10 | Documento `docs/database/sqlite-schema.drift` (esquema completo) | 2.7, 4.2 |

**Entregable:** Catálogos sincronizados, dosis append-only con snapshot, esquemas documentados.

### Fase 5: Seguridad y auditoría (Semanas 9-10)

**Objetivo:** Auditoría completa, permisos, offline authorization.

| # | Tarea | Dependencias |
|---|---|---|
| 5.1 | Esquema PostgreSQL (audit_events) | 1.5 |
| 5.2 | Auditoría automática (Spring) | 5.1 |
| 5.3 | Permisos por rol (Spring) | 1.7 |
| 5.4 | Permisos por rol (Flutter) | 1.8 |
| 5.5 | Offline authorization (Flutter) | 3.10, 5.4 |
| 5.6 | SyncScope (server-side) | 3.4 |
| 5.7 | SyncScope (Flutter) | 3.3, 5.6 |
| 5.8 | Documento `docs/api/openapi.yaml` (contrato completo) | 4.9, 3.9 |

**Entregable:** Auditoría completa, permisos funcionales, offline authorization, contrato OpenAPI.

### Fase 6: Integración y pulido (Semanas 11-12)

**Objetivo:** Pruebas end-to-end, optimización, documentación.

| # | Tarea | Dependencias |
|---|---|---|
| 6.1 | Pruebas end-to-end (sync completa) | Todas |
| 6.2 | Optimización de rendimiento | 6.1 |
| 6.3 | Documentación de despliegue | 6.2 |
| 6.4 | Pruebas de seguridad | 6.1 |
| 6.5 | Pruebas de offline prolongado | 6.1 |

**Entregable:** Sistema completo, documentado y probado.

---

## 16. Reglas de oro

1. **No hay sync sin outbox.** Toda operación offline pasa por la cola de outbox antes de ser confirmada localmente.

2. **No hay push sin idempotencia.** Cada operación tiene un `operation_id` único; el servidor lo usa para evitar reprocesamiento.

3. **No hay pull sin cursor.** El cliente mantiene un cursor del último sync; el servidor retorna solo operaciones nuevas.

4. **No hay merge automático de identidad.** La identidad de paciente (nombres, fecha nacimiento, sexo) nunca se merge automáticamente; requiere intervención humana.

5. **No hay edición de atención COMPLETED.** Una atención completada solo puede ser anulada con motivo; nunca editada.

6. **No hay DELETE de dosis.** Las dosis son append-only; solo pueden ser canceladas con motivo, actor y timestamp.

7. **No hay catálogos desde offline.** Los catálogos son globales; solo los modifica `SUPER_ADMIN` online; el offline solo los lee.

8. **No hay auth sin PIN/biometría.** La app requiere bloqueo local obligatorio para acceder.

9. **No hay sync sin scope.** Cada usuario tiene un scope de datos que puede sincronizar; el servidor lo filtra.

10. **No hay offline sin auditoría.** Todas las operaciones offline se auditan al reconectar.

---

## 17. Checklist de decisiones arquitectónicas

- [x] Monorepo (Flutter + Spring en un solo repo)
- [x] No hay `packages/api-contract` (contrato es HTTP + JSON + OpenAPI)
- [x] Dart y Java no comparten entidades
- [x] PostgreSQL puede estar en Docker local o Supabase (sin cambiar arquitectura)
- [x] `auth.users` es Supabase Auth; Spring solo lee
- [x] Spring NUNCA crea usuarios en `auth.users` (usa Supabase Management API)
- [x] `institutionId` viene del JWT, nunca del body
- [x] Offline por operación (no por usuario)
- [x] Ventana offline: 7 días default (configurable por institución)
- [x] Resolución de conflictos: ADMIN_INSTITUTION (no automática)
- [x] Scope de sync: institución + municipio
- [x] Catálogos: globales (PAI es nacional); solo `SUPER_ADMIN` los escribe
- [x] `Institution` y `institution config` (incluye ventana offline): gestionadas por `SUPER_ADMIN`
- [x] `VaccineSchedule`: incluido en MVP
- [x] Demografía: contacto auto-merge con trazabilidad; identidad nunca
- [x] Documentos derivados planificados: `docs/database/postgres-schema.sql`, `docs/database/sqlite-schema.drift`, `docs/api/openapi.yaml`
- [x] README legacy (`DATABASE_README.md`, `MODELS_README.md`) marcados para deprecación en Fase 1

---

*Documento generado: 2026-08-22*
*Última actualización: 2026-08-22*
