# Tu Vacuna PAI

Sistema de registro y consulta de vacunación del **Programa Ampliado de Inmunizaciones (PAI)** con arquitectura **offline-first**. También referido como *Mi Vacuna*.

## Descripción

Tu Vacuna PAI es una plataforma para el personal de enfermería y salud que registra y consulta atenciones de vacunación durante su jornada en instituciones de salud. Permite registrar pacientes, atenciones y dosis aplicadas, consultar historiales, gestionar el catálogo de vacunas y exportar datos.

El producto combina una experiencia operativa **offline-first** para el trabajo de campo con una **fuente de verdad remota** y sincronización controlada mediante operaciones idempotentes: una red inestable no debe bloquear el trabajo, y el estado de sincronización debe ser visible y comprensible.

## Características principales

- **Pacientes**: registro con identidad, demografía, contactos, direcciones, tutores/apoderados, antecedentes médicos, afiliación en salud (régimen y EPS) y condiciones especiales.
- **Atenciones y dosis**: registro de atención con fecha, observaciones, esquema completo e ingreso al aplicativo PAIWEB; aplicación de dosis con *snapshot* del catálogo vigente (vacuna, dosis, neumococo, laboratorio, jeringa, gotero, observación) y campos operativos.
- **Historial**: consulta de las atenciones de un paciente por documento.
- **Catálogo**: vacunas globales, habilitación por institución, opciones globales e institucionales, catálogos de referencia y catálogo de aseguradoras (EPS) por régimen.
- **Geografía**: catálogo DIVIPOLA (departamentos y municipios) para direcciones.
- **Sincronización offline**: cola de operaciones (outbox), motor de sincronización (`/sync/push` y `/sync/pull`) e idempotencia por `operationId`.
- **Identidad y autorización**: autenticación con Supabase Auth, roles y permisos, alcance institucional obligatorio.
- **Exportación de datos**.

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Mobile | Flutter (Dart SDK `^3.13.1`), Drift + SQLite cifrado (`sqlite3mc`), `supabase_flutter`, `connectivity_plus`, `flutter_secure_storage` |
| Backend | Spring Boot `4.1.1`, Java `21`, Spring Data JPA, Spring Security (OAuth2 Resource Server), Flyway, Bean Validation |
| Base de datos | PostgreSQL administrado por Supabase |
| Identidad | Supabase Auth + Edge Functions (Deno/TypeScript) |
| Calidad | ArchUnit (reglas de arquitectura), `flutter_lints`, palantir-java-format |

## Arquitectura

Monorepo con dos aplicaciones y documentación de decisiones:

- **Móvil**: regla de dependencia `UI → Controller → Use Case → Repository → Local / Remote`. Persistencia local cifrada (Drift/SQLite) con *working set* y outbox para el trabajo offline.
- **Backend**: monolito modular por capas (`Controller → Service → Repository`) con alcance institucional resuelto desde el actor, nunca desde el cliente (ADR-006, ADR-007).
- **Sincronización**: operaciones idempotentes con auditoría en la misma transacción; el contrato de sync se documenta en `docs/synchronization/`.

Referencia: `docs/architecture/architecture.md`, `docs/architecture/flutter-frontend.md`, `docs/architecture/spring-data-repositories.md`.

## Estructura del proyecto

```text
apps/mobile/            # App Flutter (offline-first)
  lib/app/              # Configuracion, tema y widgets globales
  lib/core/             # auth, network, storage, synchronization, presentation, utils
  lib/features/         # auth, dashboard, patients, attentions, catalogs, admin, users
services/api/           # API Spring Boot (modular por capas)
  src/main/java/com/pai/api/
    shared/             # security, exceptions, utilidades, reglas arquitectonicas
    identity/           # instituciones, usuarios, roles, permisos
    patients/           # pacientes y perfil extendido
    attentions/         # atenciones y dosis aplicadas
    catalog/ catalogs/  # catalogo de vacunas, referencia, EPS y geografia
    synchronization/    # push, pull y operaciones procesadas
    audit/ reports/     # auditoria y reportes
  src/main/resources/db/migration/   # migraciones Flyway (V1..V17)
supabase/               # Edge Functions y configuracion del proyecto
infra/database/         # recursos de infraestructura de base de datos
scripts/                # utilidades (smoke de aprovisionamiento)
docs/                   # documentacion (architecture, api, database, decisions, domain, engineering, synchronization)
```

## Refactor SOLID del backend

Se auditó y refactorizó el backend clínico, de catálogo e identidad para separar responsabilidades y desacoplar módulos. Detalle completo en `docs/decisions/ADR-008-aplicacion-solid-backend.md`, `docs/engineering/control-de-cambios-solid.md` y `docs/engineering/solid-backend-informe.tex`; diagrama de clases en `docs/engineering/diagrama-clases-solid.png`.

| ID | Módulo / Clase | Fallo SOLID / Antipatrón | Mejora aplicada |
|---|---|---|---|
| CC-01 | `patients` — `PatientService` | God Object / SRP | Separación en `PatientMapper`, `IdempotencyCoordinator` y `Strings`; el servicio queda como orquestador del agregado |
| CC-02 | `attentions` — `AttentionService` | DIP | Puerto `VaccineCatalogPolicy` resuelto por `catalog`; el módulo clínico deja de depender de repositorios/entidades del catálogo |
| CC-03 | `shared` — `IdempotencyCoordinator` | OCP / DRY | Ceremonia transversal de idempotencia, auditoría y registro centralizada |
| CC-04 | `catalog` — `InstitutionVaccineRepository` | SRP | El *upsert* copy-once (`insertEnabledIfAbsent`) y `setEnabledById` viven en el repositorio |
| CC-05 | `patients` / `attentions` — Mappers | SRP | `PatientMapper`, `AttentionMapper` centralizan el mapeo entidad → DTO |
| CC-06 | `IdempotencyCoordinator` + `synchronization` | OCP | Adaptación al contrato v2 de operaciones procesadas sin reescribir el motor offline |
| CC-07 | `catalog` — `VaccineService` / `InstitutionVaccineService` | DRY / SRP | `CatalogMapper` centraliza el mapeo del catálogo |
| CC-08 | `catalog` — `VaccineService` / `InstitutionVaccineService` | DRY | `CatalogRules` agrupa las validaciones compartidas de opciones |
| CC-09 | `identity` — `UserService` / `UserProvisioningService` / `UserMirrorWriter` | DRY / SRP | `IdentityMapper` centraliza el mapeo de `UserResponse` |
| CC-10 | `identity` — `UserProvisioningService` | DRY / SRP | `PermissionGuard` + `IdentityPermissions`; `AdminController` con constantes SpEL |
| CC-11 | `identity` — `UserService` / `InstitutionService` | DRY | `IdentityRules` y reutilización de `Strings` / `DocumentNormalizer` |

Principios aplicados: **SRP** (mappers, coordinador, repositorio), **OCP** (`IdempotencyCoordinator`, `VaccineCatalogPolicy`), **DIP** (`VaccineCatalogPolicy`, `PermissionGuard`) y **DRY** (`Strings`, `CatalogRules`, `IdentityRules`, `IdentityPermissions`). Se añadieron reglas de arquitectura en `ArchitectureTest` que impiden al módulo clínico depender de la persistencia del catálogo.

## Requisitos previos

- **JDK 21+** para compilar y ejecutar el backend.
- **Flutter** con Dart SDK `^3.13.1`.
- Un proyecto **Supabase** (PostgreSQL + Auth).
- **Supabase CLI** (para desplegar las Edge Functions).

En Windows, si el `JAVA_HOME` global apunta a otro JDK, fíjalo en la sesión antes de ejecutar Maven:

```powershell
$env:JAVA_HOME = "C:\ruta\al\jdk-21"
```

## Configuración

### API (`services/api/.env`)

Copia `services/api/.env.example` a `services/api/.env` y completa:

| Variable | Descripción |
|---|---|
| `SERVER_PORT` | Puerto del servidor (por defecto `8080`) |
| `DB_URL` | JDBC al PostgreSQL de Supabase (`jdbc:postgresql://...?...sslmode=require`) |
| `DB_USERNAME` | Usuario de la base de datos |
| `DB_PASSWORD` | Contraseña de la base de datos |
| `SUPABASE_AUTH_ISSUER` | `https://<ref>.supabase.co/auth/v1` |

### App móvil (`--dart-define`)

Las variables del cliente se pasan en compilación/ejecución con `--dart-define` (no se leen de un archivo):

| Variable | Descripción |
|---|---|
| `SUPABASE_URL` | URL del proyecto Supabase |
| `SUPABASE_PUBLISHABLE_KEY` | Clave pública (`sb_publishable_...`); nunca la `service_role` |
| `API_BASE_URL` | URL base del backend (por defecto `http://localhost:8080/api/v1`) |

### Edge Functions

El `SUPABASE_SERVICE_ROLE_KEY` vive **únicamente** en el entorno de las funciones de Supabase (crear/eliminar usuarios en `auth.users`); nunca en el cliente ni en Spring.

> No se deben subir `.env`, `.env.local` ni secretos al repositorio.

## Comandos

### Backend (`services/api`)

```powershell
$env:JAVA_HOME = "C:\ruta\al\jdk-21"

& .\mvnw.cmd compile      # Compila
& .\mvnw.cmd test         # Ejecuta la suite de pruebas
& .\mvnw.cmd spring-boot:run   # Levanta la API (Flyway aplica migraciones)
```

### App móvil (`apps/mobile`)

```powershell
flutter pub get                          # Dependencias
dart run build_runner build              # Genera codigo de Drift
flutter analyze                          # Analisis estatico
flutter test                             # Pruebas

```


## Migraciones

Flyway en `services/api/src/main/resources/db/migration/` (`V1..V17`):

- `V1..V4`: identidad y perfil de usuario.
- `V5..V10`: catálogo de vacunas, plantillas, pacientes, atenciones y geografía.
- `V11..V15`: motor offline (operaciones procesadas), pacientes fase 2, afiliación y condiciones, tutores/dosis, catálogos de referencia.
- `V16`: campos PAIWEB y brechas de referencia.
- `V17`: catálogo de aseguradoras (EPS).

Esquema de referencia: `docs/database/postgres-schema.sql` y `docs/database/sqlite-schema.drift`.

## Sincronización offline

El cliente mantiene un *working set* local cifrado y un outbox; el motor empuja operaciones (`/sync/push`) y aplica cambios del servidor (`/sync/pull`). Cada operación es idempotente por `operationId` y se audita en la misma transacción.

En la interfaz, el estado de sincronización es visible: una insignia de nube abre una bandeja con los registros pendientes por subir, y los avisos de la app se muestran como notificaciones superiores coherentes con el estado de conexión.

Contrato y detalle: `docs/synchronization/sync-contract.md` y `docs/synchronization/offline-engine-implementation.md`.

## Documentación

| Documento | Contenido |
|---|---|
| `docs/architecture/architecture.md` | Plan de arquitectura y decisiones de diseño |
| `docs/architecture/flutter-frontend.md` | Capas, offline-first y features del cliente Flutter |
| `docs/architecture/spring-data-repositories.md` | Repositorios (interfaces + implementación generada) |
| `docs/api/openapi.yaml` | Contrato de la API |
| `docs/domain/` | Dominio clínico, invariantes y catálogo de vacunas |
| `docs/database/` | Esquemas PostgreSQL y SQLite |
| `docs/synchronization/` | Contrato de sincronización y motor offline |
| `docs/engineering/` | Control de cambios SOLID, informe y diagrama de clases |
| `docs/formato-xls-export/` | Formato del registro diario PAI |
| `docs/decisions/` | ADRs |

### Decisiones de arquitectura (ADR)

| ADR | Tema |
|---|---|
| ADR-001 | MVP y dependencias de sincronización |
| ADR-002 | Supabase + Spring y RLS |
| ADR-003 | Ventana offline |
| ADR-004 | Versionado de la API |
| ADR-005 | Autenticación y autorización offline |
| ADR-006 | Arquitectura backend por capas |
| ADR-007 | Alcance institucional obligatorio |
| ADR-008 | Aplicación de SOLID al backend clínico y de catálogo |

## Convenciones

- **Commits**: Conventional Commits (`feat(scope):`, `fix(scope):`, `docs(scope):`, ...).
- **Idioma**: documentación e interfaz en español.
- **Seguridad**: nunca versionar secretos ni archivos `.env`.

## Estado y pendientes

- Módulo `reports`: esqueleto, sin funcionalidad.
- Sincronización offline: paridad de campos (todos los campos del registro de paciente y de dosis) y el cierre offline de detalles PAIWEB quedan como trabajo posterior.
- Auditoría de la infraestructura `audit` del coordinador: revisión menor pendiente.
