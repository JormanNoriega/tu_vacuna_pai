# Patron: Abstract Factory

## 1. Intencion

Proveer una interfaz para crear **familias de objetos relacionados** (o
dependientes) sin especificar sus clases concretas. El cliente trabaja con las
**abstracciones** (la fabrica abstracta y los productos abstractos) y no conoce
las implementaciones.

## 2. Donde esta en nuestro codigo

Modulo `reports` — exportacion del **Registro Diario PAI** en **XLSX** y **CSV**.

| Rol GoF | Clase | Ruta |
|---|---|---|
| **AbstractFactory** | `PaiReportFactory` | `reports/export/PaiReportFactory.java` |
| **ConcreteFactory** | `XlsxPaiReportFactory` | `reports/export/xlsx/XlsxPaiReportFactory.java` |
| **ConcreteFactory** | `CsvPaiReportFactory` | `reports/export/csv/CsvPaiReportFactory.java` |
| **AbstractProduct** | `ReportHeaderBuilder` | `reports/export/ReportHeaderBuilder.java` |
| **AbstractProduct** | `ReportRowWriter` | `reports/export/ReportRowWriter.java` |
| **AbstractProduct** | `ReportExporter` | `reports/export/ReportExporter.java` |
| **ConcreteProduct** | `XlsxReportHeaderBuilder` / `XlsxReportRowWriter` / `XlsxReportExporter` | `reports/export/xlsx/…` |
| **ConcreteProduct** | `CsvReportHeaderBuilder` / `CsvReportRowWriter` / `CsvReportExporter` | `reports/export/csv/…` |
| **Client** | `RegistroDiarioExportService` | `reports/service/RegistroDiarioExportService.java` |
| **Seleccion** | `ReportFactoryProvider` + `ReportFormat` | `reports/export/…` |

## 3. Que se hace abstracto y por que aplica

Lo abstracto es la **familia de productos de salida** de un reporte:

- **AbstractFactory** `PaiReportFactory`: declara como crear cada producto de la
  familia (`headerBuilder()`, `rowWriter()`, `exporter()`).
- **AbstractProducts**: `ReportHeaderBuilder`, `ReportRowWriter`, `ReportExporter`.

Aplica porque:
1. Hay **dos familias reales** (XLSX y CSV) que comparten la **misma forma** pero
   distinto detalle (POI vs texto plano).
2. Los productos de cada familia **deben usarse juntos** (encabezado + filas +
   exportador comparten el mismo buffer de salida).
3. El **cliente** los trata por igual, sin saber cual concreta usa.

Diferencia con Factory Method: Factory Method crea **un** producto; Abstract
Factory crea una **familia de productos relacionados**.

## 4. Evidencia de codigo

### 4.1 La fabrica abstracta

```java
// reports/export/PaiReportFactory.java
public interface PaiReportFactory {

  ReportHeaderBuilder headerBuilder();

  ReportRowWriter rowWriter();

  ReportExporter exporter();
}
```

### 4.2 Una fabrica concreta (familia XLSX)

```java
// reports/export/xlsx/XlsxPaiReportFactory.java
public final class XlsxPaiReportFactory implements PaiReportFactory {

  private final XlsxReportSurface surface = new XlsxReportSurface(); // workbook POI compartido

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

La familia CSV es analoga (`CsvPaiReportFactory`) pero con un `StringBuilder` como
buffer y texto delimitado por comas.

### 4.3 Los productos abstractos (y un concreto)

```java
// reports/export/ReportHeaderBuilder.java  (AbstractProduct)
public interface ReportHeaderBuilder {
  void writeHeader(List<String> titles);
}

// reports/export/xlsx/XlsxReportHeaderBuilder.java  (ConcreteProduct)
final class XlsxReportHeaderBuilder implements ReportHeaderBuilder {
  private final XlsxReportSurface surface;
  XlsxReportHeaderBuilder(XlsxReportSurface surface) { this.surface = surface; }
  @Override public void writeHeader(List<String> titles) { surface.writeHeaderRow(titles); }
}
```

`ReportRowWriter` y `ReportExporter` siguen el mismo esquema.

### 4.4 El cliente (usa solo abstracciones)

```java
// reports/service/RegistroDiarioExportService.java
PaiReportFactory factory = factoryProvider.create(format);          // <- AbstractFactory
factory.headerBuilder().writeHeader(columnTitles);                  // <- AbstractProduct
for (RegistroDiarioRow row : rows) {
  factory.rowWriter().writeRow(cellsOf(row));                       // <- AbstractProduct
}
byte[] content = factory.exporter().export();                       // <- AbstractProduct
```

### 4.5 Seleccion de la fabrica concreta

```java
// reports/export/ReportFactoryProvider.java
private final Map<ReportFormat, Supplier<PaiReportFactory>> factories =
    Map.of(
        ReportFormat.XLSX, XlsxPaiReportFactory::new,
        ReportFormat.CSV, CsvPaiReportFactory::new);
```

## 5. Las 2 familias + productos

| Familia | Fabrica concreta | Encabezado | Filas | Exportador | Sink |
|---|---|---|---|---|---|
| **XLSX** | `XlsxPaiReportFactory` | `XlsxReportHeaderBuilder` | `XlsxReportRowWriter` | `XlsxReportExporter` | `XlsxReportSurface` (POI `XSSFWorkbook`) |
| **CSV** | `CsvPaiReportFactory` | `CsvReportHeaderBuilder` | `CsvReportRowWriter` | `CsvReportExporter` | `StringBuilder` + `CsvEncoder` |

## 6. Relacion con Factory Method

Cada metodo de la **AbstractFactory** (`headerBuilder()`, `rowWriter()`,
`exporter()`) es, en si mismo, un **Factory Method**: crea un producto y deja que
la fabrica concreta decida la clase. Por eso **aplicar Abstract Factory implica
aplicar Factory Method**. Ver el ejemplo concreto en
[`../factory-method/factory-method.md`](../factory-method/factory-method.md)
(seccion "Fabrica concreta del reporte (XLSX)").

## 7. Pros y contras

| Pros | Contras |
|---|---|
| Familia coherente: los productos de un formato se usan juntos. | Mas clases (interfaces + concretas por formato). |
| **OCP**: agregar un formato = nueva ConcreteFactory + productos, sin tocar al cliente. | Si solo hubiera **un** formato, seria sobre-ingenieria. |
| El cliente no conoce las clases concretas. | Requiere un selector (`ReportFactoryProvider`). |
| Facil de testear cada familia por separado. | |

## 8. Diagrama

- Estado actual: [`abstract-factory.drawio`](./abstract-factory.drawio)

## 9. Verificacion

- `mvnw test` -> **240 pruebas, 0 fallos** (incluye `ArchitectureTest` con 17
  reglas ArchUnit en verde).
- Tests de la familia: `CsvReportExporterTest`, `XlsxReportExporterTest`,
  `ReportFactoryProviderTest`.

## 10. Extensibilidad

- **Nuevo formato** (p. ej. PDF): nuevo valor en `ReportFormat` + una
  `PaiReportFactory` concreta con sus 3 productos; registrar en
  `ReportFactoryProvider`. El cliente **no cambia** (OCP).
- **Nuevo reporte** (p. ej. Registro Mensual): reutiliza las familias por formato
  y agrega su propio conjunto de columnas/servicio.
