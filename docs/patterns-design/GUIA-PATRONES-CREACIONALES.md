# Guía de estudio — Patrones creacionales (GoF) en Tu Vacuna PAI

Guía para **estudiar y exponer** los 5 patrones creacionales del GoF tal como se
aplican en el backend (`services/api`, Spring Boot). Resume y enlaza a los docs
detallados de cada patrón en `docs/patterns-design/`.

---

## 0. Cómo usar esta guía

- Cada patrón tiene la misma plantilla: **qué es → dónde está → evidencia de
  código → cómo nos ayuda → pros/contras → guion oral (30 s) → preguntas del
  profesor**.
- Los **guiones orales** están escritos para decirlos tal cual.
- Las **preguntas del profesor** incluyen la respuesta corta y el argumento.
- Al final: **cómo se relacionan** los patrones y un **anexo** con rutas,
  diagramas y verificación.

---

## 1. Qué son los patrones creacionales

Los **patrones creacionales** abstraen el proceso de **creación de objetos**:
resuelven *quién* crea, *cómo* y *cuándo*, para no acoplar al cliente con clases
concretas. Los cinco del GoF son:

1. **Singleton** — una única instancia.
2. **Factory Method** — crear un producto dejando la clase concreta a la subclase.
3. **Abstract Factory** — crear una **familia** de productos relacionados.
4. **Builder** — construir un objeto complejo paso a paso.
5. **Prototype** — crear objetos clonando instancias existentes.

---

## 2. Tabla resumen

| Patrón | Dónde está en nuestro código | ¿Lo escribimos o ya estaba? |
|---|---|---|
| **Singleton** | Beans de Spring: `@Service`, `@Component`, `@Configuration`/`@Bean` | **Ya estaba** (lo provee el contenedor IoC) |
| **Factory Method** | (A) sync `SyncCommandHandler`; (B) catálogo `EntityFactory`; (C) reportes `XlsxPaiReportFactory` | A y B **ya estaban**; C **lo escribimos** |
| **Abstract Factory** | `PaiReportFactory` + `XlsxPaiReportFactory` / `CsvPaiReportFactory` | **Lo escribimos** (feature de exportación) |
| **Builder** | `AppliedDoseEntity.Builder` | **Lo escribimos** (refactor) |
| **Prototype** | `InstitutionOptionPrototype` + `VaccineOptionTemplateEntity.copyToInstitution` | **Lo escribimos** |

> Idea fuerza para la exposición: **no forzamos patrones**. Dos ya existían en el
> código (Singleton por Spring, Factory Method en sync/catálogo); los otros tres
> los aplicamos donde había un problema real (23 argumentos, copia duplicada,
> dos formatos de salida).

---

## 3. Singleton

### 3.1 Qué es
Garantizar que una clase tenga **una única instancia** y ofrecer un punto de
acceso global a ella.

### 3.2 Dónde está
En el backend **no escribimos ningún Singleton a mano**: lo provee el
**contenedor IoC de Spring**, que por defecto crea **una sola instancia** de cada
bean. Todo bean anotado `@Service`, `@Component`, `@Repository` o `@Configuration`
es singleton por defecto.

- `catalog/service/CatalogSelectionService.java` (`@Service`)
- `patients/service/PatientMapper.java` (`@Component`)
- `catalog/service/CatalogMapper.java` (`@Component`)
- `synchronization/service/SyncPushService.java` (`@Service`)
- `catalog/service/VaccineService.java` (`@Service`)
- `shared/security/SecurityConfig.java` (clase `@Configuration` + único `@Bean`)

### 3.3 Evidencia de código

```java
// catalog/service/CatalogSelectionService.java
@Service
public class CatalogSelectionService implements VaccineCatalogPolicy {

  private final VaccineRepository vaccines;
  private final VaccineOptionRepository vaccineOptions;

  public CatalogSelectionService(
      VaccineRepository vaccines, VaccineOptionRepository vaccineOptions) {
    this.vaccines = vaccines;
    this.vaccineOptions = vaccineOptions;
  }
}
```

```java
// shared/security/SecurityConfig.java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

  @Bean
  public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    // ...
    return http.build();
  }
}
```

**En ningún lado hay `private static X instance;` ni `getInstance()`.** La
instancia única la gestiona el contenedor y se **inyecta por constructor**.

### 3.4 Cómo nos ayuda
- Una **única instancia compartida** por toda la aplicación (servicios sin estado).
- **Inyección por constructor**: quien lo necesita lo recibe, no lo busca.
- **Testabilidad**: sin estado global, los tests instancian el servicio con mocks.
- **Ciclo de vida** gestionado por Spring (creación, orden, destrucción).

### 3.5 Pros y contras

| Pros | Contras |
|---|---|
| Una sola instancia, sin `static`/`getInstance()`. | El estado compartido debe evitarse (servicios sin estado). |
| Inyección por constructor y buen testeo. | Acopla el diseño al contenedor (estándar en Spring). |
| Ciclo de vida centralizado. | Un singleton con estado mutable sería difícil de testear. |

### 3.6 Guion oral (30 s)
> El Singleton garantiza una única instancia con acceso global. Nosotros **no lo
> escribimos a mano**: lo provee el contenedor de Spring, que por defecto crea un
> solo objeto por cada bean anotado con `@Service`, `@Component` o `@Configuration`.
> La ventaja es que **no hay `static` ni `getInstance()`**: la instancia se inyecta
> por constructor, lo que la hace testeable y sin estado global.

### 3.7 Preguntas del profesor

- **¿Dónde está la instancia única si no hay `getInstance()`?**
  En el contenedor IoC de Spring; el scope por defecto de un bean es *singleton*.
- **¿Por qué no implementar el Singleton clásico con `static instance`?**
  Rompería la inyectabilidad y la testabilidad; introduciría estado global. El
  proyecto defiende inyección por constructor.
- **¿No hay problema de concurrencia si es una sola instancia?**
  No, porque los servicios son **sin estado** (solo dependencias `final`); son
  thread-safe.
- **¿Cuál es el único bean declarado explícitamente?**
  `SecurityConfig.securityFilterChain(...)` con `@Bean` (también singleton).

---

## 4. Factory Method

### 4.1 Qué es
Definir una interfaz para crear un objeto, pero dejar que las implementaciones
concretas decidan **qué** objeto crear. El código que usa el producto no conoce
las clases concretas.

### 4.2 Dónde está
Tenemos **tres** ocurrencias:

- **(A) Despacho de comandos de sincronización**
  - Interfaz: `synchronization/service/command/SyncCommandHandler`.
  - Implementaciones: `CreatePatientCommandHandler`, `CreateAttentionCommandHandler`,
    `RegisterDoseCommandHandler`, `CompleteAttentionCommandHandler`.
  - Selección: `synchronization/service/SyncPushService` (un `Map` por `commandType`).
- **(B) Creación de opciones del catálogo**
  - `catalog/service/VaccineService` → `interface EntityFactory<E>` con
    `optionKind()` y `templateKind()`.
- **(C) Creación de la familia de salida del reporte (XLSX)** — *la que escribimos*
  - Interfaz (Creator): `reports/export/PaiReportFactory`.
  - Fábrica concreta (ConcreteCreator): `reports/export/xlsx/XlsxPaiReportFactory`.

### 4.3 Evidencia de código

**(A) El registro por `commandType` (sin `switch`):**

```java
// synchronization/service/SyncPushService.java
private final Map<String, SyncCommandHandler> handlers;

this.handlers = commandHandlers.stream()
    .collect(Collectors.toUnmodifiableMap(SyncCommandHandler::commandType, Function.identity()));

// ...
SyncCommandHandler handler = handlers.get(operation.commandType());
```

**(B) `EntityFactory` en el catálogo:**

```java
// catalog/service/VaccineService.java
@FunctionalInterface
private interface EntityFactory<E> {
  E create(UUID vaccineId, OptionRequest request, UUID actorId);
}
```

**(C) La que escribimos — Creator + ConcreteCreator:**

```java
// reports/export/PaiReportFactory.java  (Creator abstracto)
public interface PaiReportFactory {
  ReportHeaderBuilder headerBuilder();
  ReportRowWriter rowWriter();
  ReportExporter exporter();
}
```

```java
// reports/export/xlsx/XlsxPaiReportFactory.java  (ConcreteCreator)
public final class XlsxPaiReportFactory implements PaiReportFactory {
  private final XlsxReportSurface surface = new XlsxReportSurface();

  public ReportHeaderBuilder headerBuilder() { return new XlsxReportHeaderBuilder(surface); }
  public ReportRowWriter rowWriter()         { return new XlsxReportRowWriter(surface); }
  public ReportExporter exporter()           { return new XlsxReportExporter(surface); }
}
```

### 4.4 Cómo nos ayuda
- **OCP**: agregar un comando, un tipo de opción o un formato de reporte es
  **una clase nueva**; no se toca el despachador ni el cliente.
- **Desacopla** al llamador de las clases concretas.
- **Testeable**: cada handler/fábrica se prueba por separado.

### 4.5 Pros y contras

| Pros | Contras |
|---|---|
| Abierto a extensión, cerrado a modificación (OCP). | Una clase por producto (más archivos). |
| El llamador no conoce las clases concretas. | Requiere un registro/índice por clave. |
| Fácil de testear por unidad. | Hay que manejar la clave inexistente (hoy: rechazo). |

### 4.6 Guion oral (30 s)
> El Factory Method define una interfaz para crear un producto y deja que la
> implementación concreta decida la clase. En el proyecto aparece en tres lugares:
> el despacho de comandos de sincronización (un `Map` por `commandType` en vez de
> un `switch`), la creación de opciones del catálogo con `EntityFactory`, y la
> exportación XLSX, donde `XlsxPaiReportFactory` decide las clases `Xlsx*`. El
> cliente solo conoce la abstracción.

### 4.7 Preguntas del profesor

- **¿En qué se diferencia de Abstract Factory?**
  Factory Method crea **un** producto; Abstract Factory crea **una familia** de
  productos relacionados.
- **¿Por qué un `Map` de handlers en vez de un `switch`?**
  Para cumplir **OCP**: agregar un comando es una clase nueva que se auto-registra
  por `commandType`, sin editar `SyncPushService`.
- **¿Quién decide la clase concreta del producto?**
  La **ConcreteCreator** (`XlsxPaiReportFactory`), no el cliente.

---

## 5. Abstract Factory

### 5.1 Qué es
Proveer una interfaz para crear **familias de objetos relacionados** sin
especificar sus clases concretas.

### 5.2 Dónde está
Módulo `reports` — exportación del **Registro Diario PAI** en **XLSX** y **CSV**.

| Rol GoF | Clase | Ruta |
|---|---|---|
| **AbstractFactory** | `PaiReportFactory` | `reports/export/PaiReportFactory.java` |
| **ConcreteFactory** | `XlsxPaiReportFactory` | `reports/export/xlsx/XlsxPaiReportFactory.java` |
| **ConcreteFactory** | `CsvPaiReportFactory` | `reports/export/csv/CsvPaiReportFactory.java` |
| **AbstractProduct** | `ReportHeaderBuilder` / `ReportRowWriter` / `ReportExporter` | `reports/export/` |
| **ConcreteProduct** | `Xlsx*` / `Csv*` | `reports/export/xlsx` · `csv` |
| **Client** | `RegistroDiarioExportService` | `reports/service/` |
| **Selección** | `ReportFactoryProvider` + `ReportFormat` | `reports/export/` |

### 5.3 Evidencia de código

```java
// reports/export/PaiReportFactory.java  (AbstractFactory)
public interface PaiReportFactory {
  ReportHeaderBuilder headerBuilder();
  ReportRowWriter rowWriter();
  ReportExporter exporter();
}
```

```java
// reports/export/xlsx/XlsxPaiReportFactory.java  (ConcreteFactory de la familia XLSX)
public final class XlsxPaiReportFactory implements PaiReportFactory {
  private final XlsxReportSurface surface = new XlsxReportSurface(); // sink compartido

  public ReportHeaderBuilder headerBuilder() { return new XlsxReportHeaderBuilder(surface); }
  public ReportRowWriter rowWriter()         { return new XlsxReportRowWriter(surface); }
  public ReportExporter exporter()           { return new XlsxReportExporter(surface); }
}
```

```java
// reports/service/RegistroDiarioExportService.java  (cliente: solo abstracciones)
PaiReportFactory factory = factoryProvider.create(format);
factory.headerBuilder().writeHeader(COLUMN_TITLES);
for (RegistroDiarioRow row : rows) {
  factory.rowWriter().writeRow(cellsOf(row));
}
byte[] content = factory.exporter().export();
```

**Qué es `surface`:** `XlsxReportSurface` **no es un rol de GoF**, es un helper
interno del paquete `xlsx`: el **“sink” compartido** de la familia (el `Workbook`
de POI + la hoja + el estilo de encabezado + el cursor de fila). La fábrica crea
**una** superficie y se la pasa a los tres productos para que escriban **sobre el
mismo archivo**. En CSV el sink es simplemente un `StringBuilder`.

### 5.4 Cómo nos ayuda
- **Familia coherente**: los productos de un formato se usan juntos.
- **OCP**: agregar un formato = nueva `ConcreteFactory` + productos, sin tocar al
  cliente.
- **Testeable**: cada familia se prueba por separado.

### 5.5 Pros y contras

| Pros | Contras |
|---|---|
| Familia coherente; el cliente no conoce clases concretas. | Más clases (interfaces + concretas por formato). |
| **OCP**: nuevo formato sin tocar al cliente. | Si hubiera **un solo** formato, sería sobre-ingeniería. |
| Fácil de testear por familia. | Requiere un selector (`ReportFactoryProvider`). |

### 5.6 Guion oral (30 s)
> El Abstract Factory crea **familias** de objetos relacionados. Aquí la familia
> es la salida de un reporte —encabezado, filas y exportador— y hay dos familias:
> XLSX y CSV. La interfaz `PaiReportFactory` declara cómo crear los tres
> productos; `XlsxPaiReportFactory` y `CsvPaiReportFactory` deciden las clases
> concretas. El cliente, `RegistroDiarioExportService`, solo usa las abstracciones.
> Agregar un formato nuevo es una fábrica nueva, **sin tocar al cliente**.

### 5.7 Preguntas del profesor

- **¿En qué se diferencia de Factory Method?**
  Factory Method crea **un** producto; Abstract Factory crea **toda una familia**
  de productos que deben usarse juntos. De hecho, **aplicar Abstract Factory
  implica Factory Method**: cada método de `PaiReportFactory` es un Factory Method.
- **¿Por qué no un simple `if (format == XLSX)`?**
  Eso acoplaría al cliente con las clases concretas y violaría **OCP**; con la
  fábrica, agregar PDF es una clase nueva.
- **¿Por qué la fábrica se crea por exportación y no es un bean?**
  Porque mantiene estado (el `Workbook` de POI o el `StringBuilder`); no debe
  compartirse entre peticiones. `ReportFactoryProvider` crea una fábrica nueva
  por cada exportación.
- **¿Qué es `surface`?**
  El **sink compartido** de la familia XLSX (libro + hoja + estilo + cursor);
  no es un producto del patrón, es soporte interno.

---

## 6. Builder

### 6.1 Qué es
Separar la construcción de un objeto complejo de su representación, para construir
**paso a paso** y garantizar invariantes y valores por defecto en un único punto
(`build()`).

### 6.2 Dónde está
- `attentions/entity/AppliedDoseEntity.java` — clase anidada `Builder` +
  `AppliedDoseEntity.builder()`; validación en `Builder.build()`.
- `attentions/service/AttentionService.java` — `registerDose(...)` lo consume.

### 6.3 Evidencia de código

**ANTES (sin patrón): constructor telescópico de 23 argumentos + dos fases**

```java
AppliedDoseEntity dose = new AppliedDoseEntity(
    doseId != null ? doseId : UUID.randomUUID(),
    attentionId,
    selection.vaccineId(),
    /* ... 20 argumentos más, todos posicionales ... */
    now);
dose.applyOperationalFields(
    Strings.blankToNull(request.syringeLot()),
    Strings.blankToNull(request.diluent()),
    request.vialCount(),
    Strings.blankToNull(request.customObservation()));
```

**DESPUÉS (con patrón): pasos nombrados + `build()` que valida**

```java
AppliedDoseEntity dose =
    AppliedDoseEntity.builder()
        .id(doseId)                                 // null => build() genera UUID
        .attentionId(attentionId)
        .applicationDate(request.applicationDate()) // null => ahora
        .lot(request.lotId(), Strings.blankToNull(request.lotNumber()))
        .vaccine(selection.vaccineId(), selection.vaccineName(),
                 selection.vaccineCode(), selection.catalogVersion())
        .dose(selection.doseOptionId(), selection.doseLabel(), selection.doseValue())
        .laboratory(selection.laboratoryId(), selection.laboratorySnapshot())
        .operational(Strings.blankToNull(request.syringeLot()),
                     Strings.blankToNull(request.diluent()),
                     request.vialCount(),
                     Strings.blankToNull(request.customObservation()))
        .build();
```

`build()` fija los valores por defecto (`id` autogenerado, `status=REGISTERED`,
`createdAt=now`) y valida los campos obligatorios.

### 6.4 Cómo nos ayuda
- Elimina el constructor de **23 argumentos posicionales**.
- Nombra cada paso (`.vaccine(...)`, `.dose(...)`): **legible y autoexplicativo**.
- **Centraliza invariantes y defaults** en `build()` (construcción válida).
- Elimina la **inicialización en dos fases** (`applyOperationalFields`).

### 6.5 Pros y contras

| Pros | Contras |
|---|---|
| Sin constructor telescópico de 23 argumentos. | Más código: una clase `Builder` con un método por grupo. |
| Pasos nombrados y legibles. | Entidad y Builder deben mantenerse sincronizados. |
| Invariantes y defaults en `build()`. | Objeto intermedio mutable antes del `build()`. |
| Sin inicialización en dos fases. | No aporta si el objeto tuviera pocos campos. |

### 6.6 Guion oral (30 s)
> El Builder construye un objeto complejo paso a paso. Lo aplicamos en
> `AppliedDoseEntity`, que antes se creaba con un **constructor de 23 argumentos
> posicionales** y luego una segunda llamada para completarla. Con el Builder,
> cada grupo de campos tiene un método con nombre —`.vaccine(...)`, `.dose(...)`—
> y `build()` centraliza los valores por defecto y la validación. Quedó más
> legible y con una única construcción válida.

### 6.7 Preguntas del profesor

- **¿Por qué no usar simplemente un constructor o setters?**
  El constructor telescópico tenía 23 parámetros del mismo tipo, indistinguibles
  por posición, y la inicialización era en dos fases. Los setters dejarían el
  objeto en estado inválido.
- **¿Por qué `build()` valida?**
  Para garantizar la **construcción válida**: no se puede obtener una entidad sin
  los campos obligatorios.
- **¿El Builder mutable no es un problema?**
  Es un objeto **intermedio y desechable**; el objeto final (`AppliedDoseEntity`)
  sigue siendo inmutable.
- **¿Por qué no Lombok `@Builder`?**
  El proyecto no usa Lombok y necesitábamos controlar **defaults e invariantes**
  dentro de `build()`.
- **¿No bastaba con un Builder para el DTO `PatientResponse`?**
  No; ese DTO ya lo produce `PatientMapper` en un punto único (candidato evaluado
  y **no** aplicado).

---

## 7. Prototype

### 7.1 Qué es
Crear objetos nuevos **clonando instancias existentes** (prototipos), sin volver a
especificar todos sus campos. La copia se hace con un **copy-method explícito**,
no con `Cloneable`/`Object.clone()`.

### 7.2 Dónde está
- Interfaz (Prototype): `catalog/entity/InstitutionOptionPrototype.java`.
- Prototipo concreto: `catalog/entity/VaccineOptionTemplateEntity.java`
  (`copyToInstitution(...)`).
- Cliente: `catalog/service/InstitutionVaccineService.java`
  (`enable(...)` y `doClone(...)`).

### 7.3 Evidencia de código

**ANTES (sin patrón): la misma copia campo a campo, duplicada en dos métodos**

```java
// InstitutionVaccineService.enable(...)  -- y de nuevo en doClone(...)
for (VaccineOptionTemplateEntity template :
    templates.findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(vaccineId)) {
  local.save(new InstitutionVaccineOptionEntity(
      UUID.randomUUID(), institutionId, vaccineId,
      template.getFieldType(), template.getValue(), template.getDisplayName(),
      template.getSortOrder(), false, template.getId(), actor.getId(), Instant.now()));
}
```

**DESPUÉS (con patrón): el prototipo se clona a sí mismo**

```java
// catalog/entity/InstitutionOptionPrototype.java  (Prototype)
public interface InstitutionOptionPrototype {
  /** Clona este prototipo como opcion operativa de la institucion. */
  InstitutionVaccineOptionEntity copyToInstitution(UUID institutionId, UUID actorId);
}
```

```java
// catalog/entity/VaccineOptionTemplateEntity.java  (Prototype concreto)
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

### 7.4 Cómo nos ayuda
- **Elimina la duplicación** de la copia campo a campo en `enable` y `doClone`.
- El clon **conserva** los atributos del prototipo y solo cambia `id`, institución
  y actor.
- `sourceTemplateId` deja explícito el **prototipo de origen**.
- El cliente depende de la **abstracción** (`InstitutionOptionPrototype`).

### 7.5 Pros y contras

| Pros | Contras |
|---|---|
| Un solo punto de copia (DRY); antes estaba duplicada. | El “clon” es de **otro tipo** (template → opción institucional): Prototype **adaptado**, no el `clone()` clásico. |
| Sin `Cloneable`/`Object.clone()` (evita problemas con JPA). | La interfaz tiene una sola implementación. |
| `sourceTemplateId` traza el origen del clon. | El repositorio aún devuelve el tipo concreto al recorrer. |

### 7.6 Guion oral (30 s)
> El Prototype crea objetos clonando instancias existentes. Lo usamos para
> **sembrar el catálogo**: un `VaccineOptionTemplateEntity` se clona a sí mismo
> como opción operativa de la institución con `copyToInstitution(...)`. Antes esa
> copia campo a campo estaba **duplicada** en `enable` y `doClone`; ahora hay un
> único punto de copia. No usamos `Cloneable` porque da problemas con JPA y hace
> copias superficiales; usamos un método explícito.

### 7.7 Preguntas del profesor

- **¿Por qué no usar `Cloneable`/`Object.clone()`?**
  `clone()` hace **copia superficial**, lanza una excepción comprobada y da
  problemas con entidades JPA. El copy-method explícito es claro y controla el
  nuevo `id`.
- **¿Por qué dices que es un Prototype “adaptado”?**
  Porque el clon es de **otro tipo** (template → opción institucional), no una
  copia del mismo tipo. Es el caso *clone-and-specialize*.
- **¿Por qué no un `PrototypeRegistry`?**
  Porque no hay una **clave de prototipo** real: la selección ya la resuelve el
  repositorio por `vaccineId`. Un registro sería un *facade* de repositorio
  disfrazado (candidato evaluado y **no** aplicado).

---

## 8. Cómo se relacionan los patrones

- **Abstract Factory ⊃ Factory Method**: cada método de `PaiReportFactory`
  (`headerBuilder`, `rowWriter`, `exporter`) es un **Factory Method**. Aplicar
  Abstract Factory implica aplicar Factory Method.
- **Factory Method vs Abstract Factory**: uno crea **un** producto; el otro, una
  **familia** de productos relacionados.
- **Builder vs Prototype**: el **Builder** construye paso a paso desde cero; el
  **Prototype** parte de una instancia existente y la clona.
- **Singleton** es transversal: lo provee Spring para todos los beans; no se
  implementa a mano.
- **Regla del proyecto**: documentar el **código real**; no crear abstracciones
  artificiales (los candidatos que no aportaban se marcaron como *evaluados, no
  aplicados*).

---

## 9. Anexo

### 9.1 Rutas clave
- Docs detallados y diagramas: `docs/patterns-design/{singleton,factory-method,abstract-factory,builder,prototype}/`.
- Código: `services/api/src/main/java/com/pai/api/`
  - `reports/export/**` (Abstract Factory + Factory Method C).
  - `attentions/entity/AppliedDoseEntity.java` (Builder).
  - `catalog/entity/InstitutionOptionPrototype.java` + `VaccineOptionTemplateEntity.java` (Prototype).
  - `synchronization/service/SyncPushService.java` + `command/SyncCommandHandler.java` (Factory Method A).
  - `catalog/service/VaccineService.java` (`EntityFactory`, Factory Method B).

### 9.2 Diagramas (`.drawio`)
| Patrón | Diagrama |
|---|---|
| Singleton | `singleton/singleton.drawio` |
| Factory Method | `factory-method/factory-method.drawio` |
| Abstract Factory | `abstract-factory/abstract-factory.drawio` |
| Builder | `builder/builder-before.drawio` · `builder/builder-after.drawio` |
| Prototype | `prototype/prototype-before.drawio` · `prototype/prototype-after.drawio` |

### 9.3 Verificación
- `.\mvnw.cmd test` → **240 pruebas, 0 fallos**, incluye `ArchitectureTest` con
  **17 reglas ArchUnit** en verde.
- Tests propios de patrón: `AppliedDoseEntityBuilderTest`,
  `VaccineOptionTemplateEntityPrototypeTest`, `ReportFactoryProviderTest`,
  `XlsxReportExporterTest`, `CsvReportExporterTest`.

### 9.4 Candidatos evaluados y **no** aplicados (por si preguntan “¿por qué no…?”)
- `PatientResponseBuilder` — el DTO ya lo produce `PatientMapper` en un punto único.
- `DoseSelectionBuilder` — `DoseSelection` es un record ya validado; sin invariantes.
- `PrototypeRegistry` — no hay clave de prototipo real; la resuelve el repositorio.

### 9.5 Orden sugerido de exposición
1. **Singleton** (el más simple, ya provisto por Spring).
2. **Factory Method** → **Abstract Factory** (de un producto a una familia; la
   exportación XLSX enlaza ambos).
3. **Builder** (construcción paso a paso).
4. **Prototype** (clonar en vez de construir).

> Cierre: *“No forzamos patrones: dos ya existían en el código y tres los
> aplicamos donde había un problema real. Todos están documentados con evidencia
> de código y diagramas.”*
