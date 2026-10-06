# Patron: Prototype

## 1. Intencion

Crear objetos nuevos **clonando instancias existentes** (prototipos), sin volver
a especificar todos sus campos. La copia se hace con un metodo explicito
(copy-method), **no** con `Cloneable`/`Object.clone()`.

## 2. Donde esta en nuestro codigo

- Interfaz (Prototype): `catalog/entity/InstitutionOptionPrototype.java`
  (`InstitutionVaccineOptionEntity copyToInstitution(institutionId, actorId)`).
- Prototipo concreto: `catalog/entity/VaccineOptionTemplateEntity.java`
  (implementa `InstitutionOptionPrototype`; su `copyToInstitution(...)` clona el
  template hacia la institucion).
- Cliente: `catalog/service/InstitutionVaccineService.java`
  - `enable(...)` (habilita una vacuna y copia sus opciones por defecto).
  - `doClone(...)` (clona/siembra el catalogo global en la institucion).

## 3. Aclaracion importante

**Este patron lo implementamos** (a diferencia de Singleton/Factory Method, que ya
estaban). Antes la copia `template -> opcion institucional` era un
`new InstitutionVaccineOptionEntity(...)` **campo por campo, duplicado** en `enable`
y `doClone`.

## 4. Evidencia de codigo

**ANTES (sin patron): la misma copia, duplicada en dos metodos**

```java
// InstitutionVaccineService.enable(...)  -- y de nuevo en doClone(...)
for (VaccineOptionTemplateEntity template :
    templates.findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(vaccineId)) {
  local.save(new InstitutionVaccineOptionEntity(
      UUID.randomUUID(),
      institutionId,
      vaccineId,
      template.getFieldType(),
      template.getValue(),
      template.getDisplayName(),
      template.getSortOrder(),
      false,
      template.getId(),
      actor.getId(),
      Instant.now()));
}
```

**DESPUES (con patron): el prototipo se clona a si mismo**

```java
// catalog/entity/InstitutionOptionPrototype.java
public interface InstitutionOptionPrototype {
  /** Clona este prototipo como opcion operativa de la institucion. */
  InstitutionVaccineOptionEntity copyToInstitution(UUID institutionId, UUID actorId);
}
```

```java
// catalog/entity/VaccineOptionTemplateEntity.java
public class VaccineOptionTemplateEntity implements CatalogOption, InstitutionOptionPrototype {

  @Override
  public InstitutionVaccineOptionEntity copyToInstitution(UUID institutionId, UUID actorId) {
    return new InstitutionVaccineOptionEntity(
        UUID.randomUUID(),  // id nuevo del clon
        institutionId,      // institucion destino (lo unico que cambia)
        vaccineId,
        fieldType, value, displayName, sortOrder,
        false,
        id,                 // sourceTemplateId = prototipo de origen
        actorId,
        Instant.now());
  }
}
```

```java
// catalog/service/InstitutionVaccineService.java  (enable y doClone)
local.save(template.copyToInstitution(institutionId, actorId));
```

## 5. Como nos ayuda

- **Elimina la duplicacion** de la copia campo a campo en `enable` y `doClone`.
- El clon **conserva** los atributos del prototipo y solo cambia `id`, institucion
  y actor; `sourceTemplateId` deja explicito el **prototipo de origen**.
- El cliente depende de la **abstraccion** (`InstitutionOptionPrototype`).

## 6. Pros y contras

| Pros | Contras |
|---|---|
| Un solo punto de copia (DRY); antes estaba duplicada. | El "clon" es de **otro tipo** (template -> opcion institucional): Prototype **adaptado** (clone-and-specialize), no el `clone()` clasico del mismo tipo. |
| Sin `Cloneable`/`Object.clone()` (evita problemas con JPA). | La interfaz tiene una sola implementacion (abstraccion sobre todo para claridad). |
| `sourceTemplateId` traza el origen del clon. | El repositorio aun devuelve el tipo concreto al recorrer. |

## 7. Diagramas

- Antes: [`prototype-before.drawio`](./prototype-before.drawio)
- Despues: [`prototype-after.drawio`](./prototype-after.drawio)

## 8. Verificacion

- `mvnw test` -> **236 pruebas, 0 fallos, 0 errores** (incluye `ArchitectureTest`).
- Nuevo test: `VaccineOptionTemplateEntityPrototypeTest` (clona y verifica
  `institutionId`, `vaccineId`, `fieldType`, `value`, `displayName`, `sortOrder`,
  `isDefault=false`, `sourceTemplateId`).
- Red de seguridad existente: `InstitutionVaccineServiceClone`.

## 9. Candidato evaluado, no aplicado

- **`PrototypeRegistry`**: se evaluo un registro `Map<String, Prototype>`. **No
  se aplico** porque no hay una clave de prototipo real: el criterio de seleccion
  ya es la **`vaccineId`** y lo resuelve el repositorio. Un Registry aqui seria un
  *facade* de repositorio disfrazado, sin aportar valor (se descarta por
  sobre-ingenieria).
