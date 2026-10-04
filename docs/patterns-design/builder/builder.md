# Patron: Builder

## 1. Intencion

Separar la construccion de un objeto complejo de su representacion, de modo que
el mismo proceso de construccion pueda crear distintas representaciones. Aqui se
usa para construir `AppliedDoseEntity` por pasos, garantizando los valores por
defecto y las invariantes del agregado en un unico punto (`build()`).

## 2. Ubicacion en el backend

- `services/api/src/main/java/com/pai/api/attentions/entity/AppliedDoseEntity.java`
  - clase anidada `AppliedDoseEntity.Builder`
  - metodo de entrada `AppliedDoseEntity.builder()`
  - validacion e invariantes en `Builder.build()`
- `services/api/src/main/java/com/pai/api/attentions/service/AttentionService.java`
  - `registerDose(...)` consume el Builder para crear la dosis.

## 3. Antes (sin patron)

`AttentionService` construia la entidad con un constructor telescopico de **23
argumentos posicionales** y luego la terminaba con una segunda llamada
(`applyOperationalFields`), es decir, inicializacion en dos fases:

```java
Instant now = Instant.now();
Instant applicationDate = request.applicationDate() != null ? request.applicationDate() : now;

AppliedDoseEntity dose = new AppliedDoseEntity(
        doseId != null ? doseId : UUID.randomUUID(),
        attentionId,
        selection.vaccineId(),
        request.lotId(),
        Strings.blankToNull(request.lotNumber()),
        applicationDate,
        selection.doseOptionId(),
        selection.pneumococcalTypeOptionId(),
        selection.vaccineName(),
        selection.vaccineCode(),
        selection.doseLabel(),
        selection.doseValue(),
        selection.pneumococcalTypeSnapshot(),
        selection.catalogVersion(),
        selection.laboratoryId(),
        selection.laboratorySnapshot(),
        selection.syringeId(),
        selection.syringeSnapshot(),
        selection.dropperId(),
        selection.dropperSnapshot(),
        selection.observationId(),
        selection.observationSnapshot(),
        now);
dose.applyOperationalFields(
        Strings.blankToNull(request.syringeLot()),
        Strings.blankToNull(request.diluent()),
        request.vialCount(),
        Strings.blankToNull(request.customObservation()));
```

Problemas: parametros del mismo tipo indistinguibles por posicion, campos
opcionales, construccion en dos fases y ausencia de validacion centralizada.

## 4. Despues (con patron)

```java
AppliedDoseEntity dose =
        AppliedDoseEntity.builder()
                .id(doseId)                                   // null => build() genera UUID
                .attentionId(attentionId)
                .applicationDate(request.applicationDate())   // null => ahora
                .lot(request.lotId(), Strings.blankToNull(request.lotNumber()))
                .vaccine(
                        selection.vaccineId(),
                        selection.vaccineName(),
                        selection.vaccineCode(),
                        selection.catalogVersion())
                .dose(selection.doseOptionId(), selection.doseLabel(), selection.doseValue())
                .pneumococcal(
                        selection.pneumococcalTypeOptionId(),
                        selection.pneumococcalTypeSnapshot())
                .laboratory(selection.laboratoryId(), selection.laboratorySnapshot())
                .syringe(selection.syringeId(), selection.syringeSnapshot())
                .dropper(selection.dropperId(), selection.dropperSnapshot())
                .observation(selection.observationId(), selection.observationSnapshot())
                .operational(
                        Strings.blankToNull(request.syringeLot()),
                        Strings.blankToNull(request.diluent()),
                        request.vialCount(),
                        Strings.blankToNull(request.customObservation()))
                .build();
```

`build()` fija los valores por defecto (`id` autogenerado, `status=REGISTERED`,
`createdAt=now`, `cancelled*` en `null`) y valida los campos obligatorios
(`attentionId`, `vaccineId`, `vaccineNameSnapshot`, `vaccineCodeSnapshot`,
`doseLabelSnapshot`).

> Nota de diseno: el Builder recibe datos primitivos del dominio y **no** depende
> de `VaccineCatalogPolicy.DoseSelection`, para no crear un acoplamiento
> `attentions.entity -> attentions.service`.

## 5. Ya lo teniamos?

No. Antes de este refactor no existia ningun Builder en el backend; la entidad se
construia con el constructor telescopico descrito.

## 6. Pros y contras

| Pros | Contras |
|---|---|
| Elimina el constructor de 23 argumentos posicionales. | Mas codigo: una clase `Builder` con un metodo por grupo de campos. |
| Nombra cada paso (`.vaccine(...)`, `.dose(...)`): legible y autoexplicativo. | La entidad y su Builder deben mantenerse sincronizados al agregar campos. |
| Centraliza invariantes y valores por defecto en `build()` (construccion valida). | Un objeto mutable intermedio (el Builder) antes del `build()`. |
| Elimina la inicializacion en dos fases (`applyOperationalFields`). | No aporta si el objeto tuviera pocos campos (no es el caso: 23+). |
| Mantiene el constructor `protected` vacio solo para JPA/Hibernate. | |

## 7. Diagramas

- Antes: [`builder-before.drawio`](./builder-before.drawio)
- Despues: [`builder-after.drawio`](./builder-after.drawio)

## 8. Verificacion

- `mvnw test` -> **156 pruebas, 0 fallos, 0 errores** (incluye `ArchitectureTest`
  con 9 reglas ArchUnit en verde).
- Nuevo test: `AppliedDoseEntityBuilderTest` (7 pruebas) valida id autogenerado,
  `status=REGISTERED`, `createdAt`, `cancelled*` en null, snapshot/operativos y
  el rechazo de campos obligatorios faltantes.

## 9. Candidatos evaluados, no aplicados

Siguiendo la regla de no crear abstracciones artificiales, los siguientes
candidatos que aparecian en `docs/engineering/patrones-creacionales.mmd` se
evaluaron y **no** se aplicaron:

- `PatientResponseBuilder`: `PatientResponse` es un DTO derivado que ya produce
  `PatientMapper` en un unico punto; un Builder duplicaria al mapper.
- `DoseSelectionBuilder`: `DoseSelection` es un record de valores ya validado por
  `CatalogSelectionService`; no tiene invariantes ni variabilidad que proteger.
