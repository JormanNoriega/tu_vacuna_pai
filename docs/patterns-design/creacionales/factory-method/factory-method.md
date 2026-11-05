# Patron: Factory Method

## 1. Intencion

Definir una interfaz para crear un objeto, pero dejar que las implementaciones
concretas decidan **que** objeto crear. El codigo que usa el producto no conoce
las clases concretas.

## 2. Donde esta en nuestro codigo

El backend ya tiene **tres** aplicaciones del patron: dos que **reconocimos**
estudiando las clases (A y B) y una que **escribimos** como parte de la
exportacion del Registro Diario PAI (C).

### A. Despacho de comandos de sincronizacion
- Interfaz: `synchronization/service/command/SyncCommandHandler` (`commandType()`,
  `permission()`, `apply(...)`).
- Implementaciones (4): `CreatePatientCommandHandler`, `CreateAttentionCommandHandler`,
  `RegisterDoseCommandHandler`, `CompleteAttentionCommandHandler`.
- Seleccion: `synchronization/service/SyncPushService.java`
  - `:58` campo `Map<String, SyncCommandHandler> handlers;`
  - `:68-70` se construye el mapa por `SyncCommandHandler::commandType`
  - `:95` `handlers.get(operation.commandType())` -> selecciona el handler.

### B. Creacion de opciones del catalogo
- `catalog/service/VaccineService.java:175` -> `interface EntityFactory<E>`
  (`E create(vaccineId, request, actorId)`).
- `optionKind()` (`:179`) y `templateKind()` (`:201`) implementan esa fabrica:
  crean `VaccineOptionEntity` o `VaccineOptionTemplateEntity` segun el "kind".

### C. Creacion de la familia de salida del reporte (XLSX)
- Interfaz (creador abstracto): `reports/export/PaiReportFactory`
  (`headerBuilder()`, `rowWriter()`, `exporter()`).
- Fabrica concreta (creador): `reports/export/xlsx/XlsxPaiReportFactory` — cada
  metodo crea un producto concreto.
- Productos: `XlsxReportHeaderBuilder`, `XlsxReportRowWriter`,
  `XlsxReportExporter`.
- Cliente: `reports/service/RegistroDiarioExportService`.
- **Relacion con Abstract Factory**: esta misma fabrica es la `ConcreteFactory`
  de la familia XLSX. Cada metodo de la `AbstractFactory` es un **Factory
  Method**. Ver [`../abstract-factory/abstract-factory.md`](../abstract-factory/abstract-factory.md).

## 3. Aclaracion importante

**El patron ya estaba aplicado y no lo sabiamos.** Lo identificamos al leer
`SyncPushService` (un mapa de handlers por `commandType` en lugar de un `switch`)
y `VaccineService` (una `EntityFactory` por tipo de opcion).

## 4. Evidencia de codigo

### A. Despacho de comandos (`/sync/push`)

La interfaz del producto a crear/ejecutar:

```java
// synchronization/service/command/SyncCommandHandler.java
public interface SyncCommandHandler {

  /** {@code commandType} del comando que atiende. */
  String commandType();

  /** Permiso requerido, o {@code null} si el comando no exige permiso. */
  String permission();

  /** Aplica el comando. Las excepciones de dominio las clasifica el orquestador. */
  void apply(UUID actorId, String operationId, SyncOperation operation);
}
```

Una implementacion concreta ("fabrica" del paciente):

```java
// synchronization/service/command/CreatePatientCommandHandler.java
@Component
public class CreatePatientCommandHandler implements SyncCommandHandler {

  public static final String COMMAND = "CREATE_PATIENT";

  private final PatientService patients;
  private final SyncPayloadConverter payload;

  public CreatePatientCommandHandler(PatientService patients, SyncPayloadConverter payload) {
    this.patients = patients;
    this.payload = payload;
  }

  @Override
  public String commandType() {
    return COMMAND;
  }

  @Override
  public String permission() {
    return "PATIENT_WRITE";
  }

  @Override
  public void apply(UUID actorId, String operationId, SyncOperation operation) {
    patients.create(
        actorId,
        operationId,
        operation.aggregateId(),
        payload.convert(operation, CreatePatientRequest.class));
  }
}
```

El **registro** que selecciona la implementacion (sin `switch`), en
`SyncPushService`:

```java
// synchronization/service/SyncPushService.java
private final Map<String, SyncCommandHandler> handlers;

public SyncPushService(
    IdentityService identity,
    PatientMergeRequestService mergeRequests,
    ProcessedOperationsPort processedOperations,
    List<SyncCommandHandler> commandHandlers) {
  // ...
  this.handlers = commandHandlers.stream()
      .collect(
          Collectors.toUnmodifiableMap(SyncCommandHandler::commandType, Function.identity()));
}

// ...
SyncCommandHandler handler = handlers.get(operation.commandType());
if (handler == null) {
  reject(rejected, outcomes, operationId, REASON_INVALID_PAYLOAD,
      "Comando no soportado: " + operation.commandType());
  continue;
}
```

### B. Creacion de opciones del catalogo

`EntityFactory<E>` + las dos fabricas concretas (`optionKind` / `templateKind`):

```java
// catalog/service/VaccineService.java
@FunctionalInterface
private interface EntityFactory<E> {
  E create(UUID vaccineId, OptionRequest request, UUID actorId);
}

private OptionKind<VaccineOptionEntity> optionKind() {
  return new OptionKind<>(
      options,
      options::save,
      mapper::toGlobalOption,
      CatalogRules::requireGlobalOptionType,
      new OptionMessages(
          "Opcion no existe.",
          "El tipo de opcion no puede cambiarse.",
          "La opcion fue modificada por otro usuario."),
      (vaccineId, r, actorId) -> new VaccineOptionEntity(
          UUID.randomUUID(),
          vaccineId,
          r.fieldType(),
          r.value(),
          r.displayName(),
          r.sortOrder(),
          r.isDefault(),
          actorId,
          Instant.now()));
}

private OptionKind<VaccineOptionTemplateEntity> templateKind() {
  return new OptionKind<>(
      templates,
      templates::save,
      mapper::toTemplate,
      CatalogRules::requireTemplateType,
      new OptionMessages(
          "Template no existe.",
          "El tipo de template no puede cambiarse.",
          "El template fue modificado por otro usuario."),
      (vaccineId, r, actorId) -> new VaccineOptionTemplateEntity(/* ... */));
}
```

El CRUD compartido recibe el "kind" y crea/valida por la interfaz, sin conocer la
clase concreta:

```java
@Transactional
public OptionResponse createOption(UUID actor, UUID vaccine, OptionRequest r) {
  return create(optionKind(), actor, vaccine, r);
}

@Transactional
public OptionResponse createTemplate(UUID actor, UUID vaccine, OptionRequest r) {
  return create(templateKind(), actor, vaccine, r);
}
```

### C. Fabrica concreta del reporte (XLSX)

El creador abstracto (la `AbstractFactory` del reporte):

```java
// reports/export/PaiReportFactory.java
public interface PaiReportFactory {

  ReportHeaderBuilder headerBuilder();

  ReportRowWriter rowWriter();

  ReportExporter exporter();
}
```

La fabrica concreta: cada metodo es un **Factory Method** que decide la clase
concreta del producto (aqui, las versiones XLSX):

```java
// reports/export/xlsx/XlsxPaiReportFactory.java
public final class XlsxPaiReportFactory implements PaiReportFactory {

  private final XlsxReportSurface surface = new XlsxReportSurface(); // buffer POI compartido

  @Override
  public ReportHeaderBuilder headerBuilder() {
    return new XlsxReportHeaderBuilder(surface);
  }

  @Override
  public ReportRowWriter rowWriter() {
    return new XlsxReportRowWriter(surface);
  }

  @Override
  public ReportExporter exporter() {
    return new XlsxReportExporter(surface);
  }
}
```

El cliente crea y usa los productos **a traves de la abstraccion** (no conoce
`Xlsx*` ni `Csv*`):

```java
// reports/service/RegistroDiarioExportService.java
PaiReportFactory factory = factoryProvider.create(format);
factory.headerBuilder().writeHeader(columnTitles);
factory.rowWriter().writeRow(cellsOf(row));
byte[] content = factory.exporter().export();
```

## 5. Como nos ayuda

- **OCP**: agregar un comando, un tipo de opcion o un **formato de reporte**
  nuevo es **una clase nueva**; no se toca el despachador (`SyncPushService`),
  ni el algoritmo del catalogo, ni el cliente del reporte.
- **Desacopla** al llamador de las clases concretas: solo conoce la interfaz.
- **Testeable**: cada handler/fabrica se prueba por separado; el despacho se
  prueba con `SyncPushServiceTest` y las familias con `XlsxReportExporterTest` /
  `CsvReportExporterTest`.

## 6. Pros y contras

| Pros | Contras |
|---|---|
| Abierto a extension, cerrado a modificacion (OCP). | Una clase por producto (mas archivos). |
| El llamador no conoce las clases concretas. | Requiere un registro/indice por clave. |
| Facil de testear por unidad. | Si la clave no existe hay que manejar el caso (hoy: rechazo `INVALID_PAYLOAD`). |

## 7. Diagrama

- Estado actual: [`factory-method.drawio`](./factory-method.drawio)

## 8. Verificacion

- `mvnw test` -> todas las pruebas en verde (incluye `SyncPushServiceTest` y las
  pruebas del catalogo con `EntityFactory`).
