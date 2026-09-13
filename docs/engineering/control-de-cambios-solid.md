# Formato de Control de Cambios — Refactor SOLID Backend

**Proyecto:** Proyecto Integrador — Plataforma de Vacunación (Pai)
**Entregable:** Taller No. 3 — Calidad de Código
**Rama base del refactor:** `771a45b` (master antes del PR #1)
**Estado sobre el que se documenta:** rama `features-brayan` con el PR #1 (`features-Jorman`, motor offline) integrado
**Autor del refactor:** Brayan (brayanjr1019@gmail.com)
**Fecha:** 2026-09-13

---

## Contexto

El primer refactor SOLID se aplicó sobre la base clínica estable (`771a45b`, 116 pruebas en verde) en los
módulos `attentions`, `catalog`, `patients` y `shared`. Posteriormente el integrante Jorman montó el **motor
offline** (módulo `synchronization`, pacientes fase 2, catálogos de referencia, migraciones V11–V15, y el
cliente Flutter offline) y lo fusionó a `master` vía PR #1. Este documento registra los cambios de calidad
aplicados sobre el **estado integrado** de ambas líneas: el refactor original + las adaptaciones necesarias
para convivir con el cambio de contrato que trajo el motor offline.

Alcance de la revisión SOLID (intersección de ambas ramas):

| Módulo | Auditar | Notas |
|---|---|---|
| attentions | Sí | Refactor + delta offline (overloads con aggregate_id, dosis expandidas) |
| catalog | Sí | Puertos/política + repositorio con queries nativas |
| patients | Sí | Refactor + fase 2 (afiliación, condiciones, perfil extendido) |
| shared | Sí | Coordinador, Mappers, Strings, reglas ArchUnit |
| synchronization | Integrado sin reescribir | Motor offline de Jorman (nuevo módulo) |
| identity / reports / geo catalogs | Pendiente | No modificados por ninguno de los dos |

---

## Tabla de Control de Cambios

| ID | Archivo / Clase Modificada | Fallo SOLID / Antipatrón | Descripción del Problema | Mejora Aplicada | Severidad |
|---|---|---|---|---|---|
| CC-01 | `patients/service/PatientService.java` | God Object / SRP | El servicio de ~600 líneas orquestaba la creación, el mapeo entidad→DTO, la ceremonia de idempotencia y auditoría, y helpers repetidos (blankToNull, parseOperationId) en un solo lugar, dificultando testing y evolución. | Se separaron responsabilidades: `PatientMapper` (mapeo), `IdempotencyCoordinator` (find → ejecutar → auditar → registrar) y `Strings` (helpers); el servicio quedó como orquestador del agregado, incluida la fase 2 (afiliación, condiciones, perfil extendido). | Alta |
| CC-02 | `attentions/service/AttentionService.java` | DIP violado | El servicio inyectaba repositorios y entidades del módulo `catalog` (VaccineRepository, InstitutionVaccineOptionRepository, etc.), acoplando módulos de dominio distintos y atando la resolución del catálogo a la implementación concreta. | Se introdujo `VaccineCatalogPolicy` como puerto en el dominio de attenciones (resuelto por una implementación en `catalog`); el servicio solo declara la política. Una regla ArchUnit impide importar `catalog.entity`/`catalog.repository` desde `attentions`. | Alta |
| CC-03 | `shared/application/IdempotencyCoordinator.java` | OCP / DRY | La ceremonia transversal de la idempotencia (D3) y el parseo de `operationId` estaban duplicados en PatientService y AttentionService; agregar una operación nueva implicaba replicarla. | Se extrajo el coordinador transversal: los servicios aportan solo el cuerpo (`Supplier<WriteResult<T>>`), el contexto de auditoría y el payload; el coordinador ejecuta, audita y registra. | Media |
| CC-04 | `catalog/repository/InstitutionVaccineRepository.java` | SRP | El upsert "copy-once" para habilitar una vacuna en la institución se ejecutaba desde `InstitutionVaccineService` con SQL nativo vía `EntityManager`, dejando la persistencia fuera del repositorio. | Se movió la query al repositorio con `@Modifying`/`@Query` (`setEnabledById`, `insertEnabledIfAbsent` nativo con `ON CONFLICT DO NOTHING`); el servicio solo orquesta. | Media |
| CC-05 | `patients/service/PatientMapper.java`, `attentions/service/AttentionMapper.java` | SRP | El mapeo entidad→DTO (incluidos los snapshots de catálogo y el perfil fase 2) vivía dentro de los servicios de negocio. | Mappers dedicados (`@Component`) producen `PatientResponse`/`AttentionResponse`/`AppliedDoseResponse`; el dominio delega la conversión y no mezcla persistencia con representación. | Media |
| CC-06 | `IdempotencyCoordinator` + `synchronization/service/ProcessedOperationsService.java` | OCP ante cambio de contrato | El PR #1 de Jorman evolucionó el contrato de `ProcessedOperationsService.record` (firma de 6 argumentos con `institutionId` y `payload`) e introdujo el motor offline (`/sync/push`, `/sync/pull`, cola Flutter). El coordinador previo (4 args) quedaba incompatible. | El coordinador se adaptó a la firma 6-arg manteniendo estable el contrato para los servicios de negocio (el payload viaja como `Supplier<Object>`; en dosis incluye `attentionId` para que `/sync/pull` reconstruya la operación). El módulo `synchronization` y el motor offline se integraron sin reescribirlos. | Alta |

> **Severidad:** Alta = riesgo de bugs / acoplamiento arquitectónico crítico; Media = mejora estructural relevante; Baja = higiene de código.

---

## Principios SOLID aplicados (mínimo exigido: 3)

| Principio | Dónde se aplica |
|---|---|
| **SRP** — Responsabilidad Única | Mappers (`PatientMapper`, `AttentionMapper`), coordinador (ceremonia), repositorio (persistencia), servicio (orquestación). CC-01, CC-04, CC-05 |
| **OCP** — Abierto/Cerrado | `IdempotencyCoordinator` añade operaciones sin tocar el coordinador (CC-03, CC-06); `VaccineCatalogPolicy` permite resolver el catálogo sin tocar attenciones |
| **DIP** — Inversión de Dependencias | `AttentionService` depende de `VaccineCatalogPolicy` (abstracción), no de `catalog.repository`. CC-02 |
| **DRY** (complementario) | Helpers comunes en `Strings` (`blankToNull`, `safe`); payload unitario del comando de dosis |

---

## Checklist de funcionalidades MVP preservadas (integración)

Tabla que verifica que el refactor **no perdió** ninguna funcionalidad base tras integrar el PR #1:

- [x] Alta de paciente con normalización/validación de documento, alcance por institución (ADR-007) e idempotencia por `operationId` (D3).
- [x] Perfil extendido de paciente fase 2: identidad expandida, demografía (orientación sexual), contactos, direcciones, tutores, antecedentes, **afiliación, condiciones especiales y condición de usuario** (merge request de sincronización).
- [x] Flujo de atención: alta, actualización con bloqueo optimista, completado idempotente, anulación con motivo, listado por paciente.
- [x] Registro de dosis con **snapshot del catálogo** vigente (vacuna, dosis, neumococo, laboratorio, jeringa, gotero, observación) y campos operativos (`syringeLot`, `diluent`, `vialCount`, `customObservation`); cancelación append-only.
- [x] Habilitar vacuna en institución (upsert copy-once) y re-clonación respetando deshabilitaciones locales.
- [x] Auditoría en la misma transacción para todas las escrituras.
- [x] **Motor offline integrado**: `/sync/push` y `/sync/pull`, `ProcessedOperationsService` v2 (payload), migraciones V11–V15 aplicadas (schema en v15), cliente Flutter offline (sync queue/engine) y sus pruebas.
- [x] Catálogos de referencia (`ReferenceCatalog`) y su API.

---

## Verificación sobre el estado integrado

- [x] `mvnw compile` → **BUILD SUCCESS** (sin errores).
- [x] `mvnw test` → **127 pruebas, 0 fallos, 0 errores** (incluye `ArchitectureTest` ArchUnit: 9 reglas en verde, tests de sincronización de Jorman: 11, pacientes fase 2: 10, attentions: 8).
- [x] Smoke boot con Supabase → `Started ApiApplication` (≈120 s), Tomcat en 8080, Flyway aplicó **V11–V15 → schema en v15**, sin errores de wiring (backend cerrado tras la verificación).
- [x] Ramas: integración en `features-brayan`; `master` sin tocar.

## Pendientes documentados

- Módulos `identity`, `reports` y catálogos geográficos aún no auditados con las reglas ArchUnit (no fueron modificados por ninguna de las dos ramas).
- Unificar los conteos de pruebas en `ADR-008` (114 base + 2 ArchUnit) y `solid-backend-informe.tex` (112 unit + 4 ArchUnit) al valor verificado sobre el estado integrado: **127**.