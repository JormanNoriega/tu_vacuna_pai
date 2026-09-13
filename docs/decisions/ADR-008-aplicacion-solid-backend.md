# ADR-008: Aplicación de SOLID al backend clínico y de catálogo

- Estado: Aceptada
- Fecha: 2026-09-12
- Alcance: pacientes, atenciones (dosis), catálogo de vacunas, shared

## Contexto

Los servicios de negocio del módulo clínico (`AttentionService`,
`PatientService`) y del catálogo (`VaccineService`, `InstitutionVaccineService`)
crecieron hasta concentrar demasiadas responsabilidades y dependencias, lo que
dificulta modificar una regla sin tocar el resto y probar cada pieza por
separado. Se detectaron estas violaciones:

1. **DIP (Inversion de dependencias)** — `AttentionService` inyectaba cuatro
   repositorios JPA del módulo `catalog` (`VaccineRepository`,
   `VaccineOptionRepository`, `InstitutionVaccineRepository`,
   `InstitutionVaccineOptionRepository`) además de `PatientRepository`: con 11
   colaboradores, el módulo clínico dependía directamente de la persistencia de
   otro módulo.
2. **SRP (Responsabilidad única)** — `AttentionService` (429 líneas) y
   `PatientService` (502 líneas) mezclaban orquestación, validación de
   catálogo, helpers de normalización y mapeo entidad→DTO privado
   (`toResponse`, `toDoseResponse`).
3. **OCP (Abierto/cerrado)** — la ceremonia idempotente
   `processedOperations.find → cuerpo → audit.record → processedOperations.record`
   se duplicaba en `create`, `registerDose` y `PatientService.create`; añadir
   una operación nueva implicaba replicar la secuencia a mano.
4. **DRY y gobierno de permisos** — el método privado `actor(actorId,
   permission)` se duplicaba en `VaccineService` e `InstitutionVaccineService`;
   los helpers `blankToNull`, `safe` y `parseOperationId` se duplicaban en cada
   servicio; `InstitutionVaccineService` usaba `EntityManager` con SQL nativo
   duplicado en `enable` y `doClone` para el upsert copy-once.
5. **Código muerto** — `InstitutionVaccineRepository.setEnabled(id, version,
   enabled)` no se usaba en ningún lugar (el commit remoto `16460fc` ya lo
   eliminó; en local seguía presente).

Se respeta explícitamente el **LSP**: no existen jerarquías de herencia en el
alcance clínico/catálogo, por lo que el principio no aplica y no introduce
trabajo.

## Decisión

Refactorizar el alcance aplicando los principios de forma verificable, con la
convención por capas de ADR-006 (sin hexagonal) e integrando el
`operationId` (D3) y la auditoría como ceremonia transversal. La
documentación antes/después se detalla en
`docs/engineering/solid-backend-informe.tex`.

### DIP: puerto de selección del catálogo

- Nuevo puerto `attentions/service/VaccineCatalogPolicy.java` con un único
  método `resolve(ResolutionRequest)` que devuelve el snapshot inerte
  `DoseSelection` (sin exponer entidades JPA del catálogo).
- Nueva implementación `catalog/service/CatalogSelectionService.java` que
  encapsula validaciones que vivían en `AttentionService` (vacuna activa y
  habilitada en la institución, opciones globales válidas, opciones operativas
  institucionales) y construye el snapshot.
- `AttentionService` pasa de 11 a 9 colaboradores y deja de depender de
  `.catalog.repository` y `.catalog.entity`. `ProcessedOperationsService` deja
  de inyectarse en los servicios de negocio (su uso vive en el coordinador).

### SRP: mappers de respuesta

- `attentions/service/AttentionMapper.java` y
  `patients/service/PatientMapper.java` concentran el mapeo entidad→DTO
  (`AttentionResponse`, `AppliedDoseResponse`, `PatientResponse` con sus
  subentidades). Cada servicio los inyecta y conserva solo la orquestación.

### OCP: coordinador de escrituras idempotentes

- Nuevo `shared/application/IdempotencyCoordinator.java` encapsula la
  ceremonia `find → cuerpo → auditar → registrar`. El servicio aporta solo el
  cuerpo (`Supplier<WriteResult<T>>`) y el contexto de auditoría diferido
  (`Supplier<AuditContext>`), de modo que en un replay idempotente no se
  ejecuta absolutamente nada (ni siquiera se resuelve el actor).
  `execute` (con idempotencia) se usa en `create`/`registerDose`;
  `executeAudited` (sin idempotencia) en `update`, `complete`,
  `updateContact`, `updateDemographics`, `updateMedicalHistories`.
  Las cancelaciones con payload de auditoría compuesto se dejan fuera del
  coordinador por su `Cancellation` específico.

### DRY y gobierno de permisos

- `shared/security/PermissionGuard.java` reemplaza el `actor()` privado
  duplicado en `VaccineService` e `InstitutionVaccineService`.
- `shared/util/Strings.java` centraliza `blankToNull`, `trimToNull` y `safe`.
- `InstitutionVaccineRepository` reemplaza el `setEnabled` muerto por
  `setEnabledById(id, enabled)` (JPQL con `WHERE id`) y el upsert nativo
  `insertEnabledIfAbsent(institution, vaccine, actor)` (`INSERT ... ON
  CONFLICT DO NOTHING`, devuelve 1/0). Con esto se elimina el
  `EntityManager` de `InstitutionVaccineService` (DIP: la query vive en el
  repositorio).

### Reglas arquitectónicas nuevas

Se añaden dos reglas a `ArchitectureTest.java`:

- `attentions_must_not_depend_on_catalog_repositories_or_entities`: el módulo
  clínico no referencia `.catalog.repository` ni `.catalog.entity`.
- `policy_implementations_live_in_catalog`: las implementaciones de
  `VaccineCatalogPolicy` residen en el módulo `catalog`.

## Antes / Después (resumen)

| Clase | Antes | Después |
| --- | --- | --- |
| `AttentionService` | 429 líneas, 11 colaboradores, 4 repos catalog + 4 helpers duplicados + mapeo privado | 336 líneas, 9 colaboradores, consulta vía `VaccineCatalogPolicy`, mapeo en `AttentionMapper`, ceremonia en `IdempotencyCoordinator` |
| `PatientService` | 502 líneas, 10 colaboradores, mapeo privado de 60 líneas, helpers duplicados | 433 líneas, mapeo en `PatientMapper`, ceremonia en `IdempotencyCoordinator`, helpers en `Strings` |
| `VaccineService` | `IdentityService` + `actor()` privado y código de default`isDefault` | `PermissionGuard`, misma lógica |
| `InstitutionVaccineService` | `IdentityService` + `EntityManager` con SQL nativo duplicado (upsert copy-once) | `PermissionGuard` + repositorio cuyo upsert nativo vive en `InstitutionVaccineRepository` |
| `InstitutionVaccineRepository` | `setEnabled` muerto (no usado) | `setEnabledById` + `insertEnabledIfAbsent` (nativo copy-once) |

## Consecuencias

### Positivas

- El módulo clínico queda desacoplado de la persistencia del catálogo y solo
  conoce su propio puerto; la frontera de módulos es verificable con ArchUnit.
- Añadir una escritura idempotente nueva exige solo el cuerpo de la operación
  (OCP): el coordinador ya no cambia.
- Los mappers y helpers se prueban y evolucionan por separado (SRP).
- Se elimina código muerto y SQL nativo duplicado; la query upsert queda
  declarada en el repositorio (DIP).
- 116 tests en verde sobre la base pre-merge; **127 tests tras integrar el
  PR #1** (ver la actualización al final del ADR).

### Negativas

- `AttentionService` y `PatientService` resuelven el actor en el cuerpo y en
  el contexto de auditoría (la doble resolución es intencional para que el
  replay no ejecute trabajo); es un lookup en memoria, no una extra de I/O.
- `catalog` ahora referencia el puerto definido en `..attentions.service..`;
  es la única dependencia entre módulos fuera de la capa compartida y está
  cubierta por regla Arquitectural.
- `UserProvisioningService` queda fuera del alcance (riesgo alto); el patrón
  `PermissionGuard`/`Strings` queda disponible para integrarlo luego.

## Verificación

```text
mvnw.cmd compile && mvnw.cmd test
→ 116 tests, 0 fallos (BUILD SUCCESS), sin base de datos
→ 127 tests, 0 fallos (BUILD SUCCESS) tras integrar el PR #1 (ver actualización)
```

## Actualización — integración del PR #1 (motor offline, 2026-09-13)

Estado documentado sobre la rama `features-brayan` (`fba543c`, merge de
`bb3a987` PR #1 de `features-Jorman`). El motor offline de Jorman evolucionó el
contrato de `ProcessedOperationsService` (`record` de 6 argumentos con
`institutionId` y `payload`) e introdujo pacientes fase 2 (afiliación,
condiciones, perfil extendido), catálogos de referencia, migraciones V11–V15 y
el cliente Flutter offline. Consecuencias sobre el refactor:

- `IdempotencyCoordinator` se adaptó a la firma v2 manteniendo estable el
  contrato para los servicios de negocio (el payload viaja como
  `Supplier<Object>`); el payload de dosis conserva `attentionId` para que
  `/sync/pull` reconstruya la operación.
- `PatientService`/`AttentionService` conservan el patrón SOLID
  (coordinator + mapper + `VaccineCatalogPolicy`) y suman overloads
  offline-first que respetan el `aggregate_id` del cliente.
- `PatientMapper`/`AttentionMapper` se ampliaron al perfil fase 2.
- El módulo `synchronization` (nuevo) se integró sin reescribirse.
- Reglas ArchUnit sin cambios y en verde tras el merge.
- Verificado: `mvnw test` → **127 tests, 0 fallos**, y smoke boot con Supabase
  → Flyway aplicó V11–V15 (schema v15). Backend cerrado tras verificar.