# Exportacion de reportes PAI (backend)

Documento de la funcionalidad de **exportacion de reportes** del backend
(`services/api`). Implementa el patron **Abstract Factory** (GoF) para generar el
**Registro Diario** PAI en **XLSX** y **CSV**.

> **Alcance actual (backend-only):** la funcionalidad esta lista en el backend; el
> cliente Flutter **aun no la consume**. Se documenta el contrato para integrarla
> despues. El diseno queda **abierto** a nuevos reportes (p. ej. **Registro
> Mensual**) y a nuevos formatos.

---

## 1. Objetivo

Permitir que una institucion **exporte su Registro Diario** (una fila por dosis
aplicada) en un rango de fechas, en **XLSX** o **CSV**, lista para el reporte
oficial del PAI.

- Fuente de datos: `attentions` (atenciones + `applied_doses`) y `patients`
  (identidad del paciente).
- La institucion se **deriva del actor** (ADR-007); el cliente **nunca** la envia.

---

## 2. Patron Abstract Factory

El reporte se compone de una **familia de productos relacionados** —encabezado,
filas y exportador— que **depende del formato**. Se modela con Abstract Factory:

| Rol GoF | En el codigo |
|---|---|
| **AbstractFactory** | `PaiReportFactory` |
| **ConcreteFactory** | `XlsxPaiReportFactory`, `CsvPaiReportFactory` |
| **AbstractProduct** | `ReportHeaderBuilder`, `ReportRowWriter`, `ReportExporter` |
| **ConcreteProduct** | `XlsxReportHeaderBuilder`/`RowWriter`/`Exporter`, `CsvReportHeaderBuilder`/`RowWriter`/`Exporter` |
| **Client** | `RegistroDiarioExportService` |

- Las fabricas concretas **comparten un mismo sink**: `XlsxReportSurface`
  (workbook de POI) o `StringBuilder` (CSV), de modo que los tres productos
  escriben sobre el mismo artefacto.
- La seleccion de fabrica la hace `ReportFactoryProvider` (formato → AbstractFactory).

```java
public interface PaiReportFactory {
  ReportHeaderBuilder headerBuilder();
  ReportRowWriter rowWriter();
  ReportExporter exporter();
}
```

Uso (cliente):

```java
PaiReportFactory factory = factoryProvider.create(format);
factory.headerBuilder().writeHeader(columnTitles);
for (row : rows) factory.rowWriter().writeRow(cellsOf(row));
byte[] content = factory.exporter().export();
```

---

## 3. Estructura de paquetes

```
com.pai.api.reports
├── controller/ReportController            GET /api/v1/reports/registro-diario
├── service/
│   ├── RegistroDiarioQuery               (puerto DIP; lo implementa attentions)
│   ├── PatientIdentityQuery              (puerto DIP; lo implementa patients)
│   └── RegistroDiarioExportService       (Client del patron)
├── domain/
│   ├── RegistroDiarioRow                 (fila final del reporte)
│   ├── RegistroDiarioDoseData            (dosis + atencion; lo devuelve attentions)
│   ├── PatientIdentity                   (identidad; la devuelve patients)
│   └── ReportColumn                      (titulo + extractor de valor)
└── export/
    ├── PaiReportFactory                  (AbstractFactory)
    ├── ReportHeaderBuilder               (AbstractProduct)
    ├── ReportRowWriter                   (AbstractProduct)
    ├── ReportExporter                    (AbstractProduct)
    ├── ReportFormat                      (enum XLSX/CSV)
    ├── ReportFactoryProvider             (formato -> AbstractFactory)
    ├── ExportedReport                    (content + filename + contentType)
    ├── xlsx/XlsxPaiReportFactory · XlsxReportSurface · Xlsx*products
    └── csv/CsvPaiReportFactory · CsvEncoder · Csv*products
```

Implementaciones de los puertos (DIP):

- `attentions.service.RegistroDiarioQueryService implements RegistroDiarioQuery`
- `patients.service.PatientIdentityQueryService implements PatientIdentityQuery`

---

## 4. Endpoint

**`GET /api/v1/reports/registro-diario`**

| Parametro | Tipo | Obligatorio | Descripcion |
|---|---|---|---|
| `from` | `Instant` ISO-8601 | Si | Inicio del rango (inclusive). Ej: `2026-01-01T00:00:00Z` |
| `to` | `Instant` ISO-8601 | Si | Fin del rango (inclusive). Ej: `2026-01-31T23:59:59Z` |
| `format` | `xlsx` \| `csv` | No (default `xlsx`) | Formato de salida |

**Respuesta:** `200 OK` con el archivo binario.

- `Content-Type`: `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` (XLSX) o `text/csv; charset=UTF-8` (CSV).
- `Content-Disposition`: `attachment; filename="registro-diario-<institucion>-<fecha>.xlsx|csv"`.
- Sin datos en el rango: responde `200` con el archivo **solo con el encabezado**.

**Permiso:** `ATTENTION_READ` (vacunadores y administradores ya lo tienen; no
requiere migracion).

**Errores:**

- `400` si `format` no es `xlsx`/`csv` (`"Formato no soportado: <v>. Usa xlsx o csv."`).
- `400` si `from`/`to` no son ISO-8601.
- `403` si el actor no tiene `ATTENTION_READ`.
- `401` sin JWT valido.

**Ejemplo (curl):**

```bash
curl -G 'http://localhost:8080/api/v1/reports/registro-diario' \
  --data-urlencode 'from=2026-01-01T00:00:00Z' \
  --data-urlencode 'to=2026-01-31T23:59:59Z' \
  --data-urlencode 'format=csv' \
  -H "Authorization: Bearer <JWT>" \
  -o registro.csv
```

---

## 5. Columnas del reporte (Registro Diario)

Una fila por **dosis aplicada** (no anulada). Orden fijo:

| # | Columna | Origen |
|---|---|---|
| 1 | Consecutivo | `attentions.consecutive` |
| 2 | Fecha de atencion | `attentions.attention_date` (`yyyy-MM-dd HH:mm`, UTC) |
| 3 | Tipo de identificacion | `patients.document_type` |
| 4 | Numero de identificacion | `patients.document_number` |
| 5 | Primer nombre | `patients.first_name` |
| 6 | Segundo nombre | `patients.second_name` |
| 7 | Primer apellido | `patients.last_name` |
| 8 | Segundo apellido | `patients.second_last_name` |
| 9 | Fecha de nacimiento | `patients.birth_date` (`yyyy-MM-dd`) |
| 10 | Sexo | `patients.sex` (`MALE`/`FEMALE`) |
| 11 | Vacuna | `applied_doses.vaccine_name_snapshot` |
| 12 | Codigo | `applied_doses.vaccine_code_snapshot` |
| 13 | Dosis | `applied_doses.dose_label_snapshot` |
| 14 | Lote | `applied_doses.lot_number` |
| 15 | Laboratorio | `applied_doses.selected_laboratory_snapshot` |
| 16 | Jeringa | `applied_doses.selected_syringe_snapshot` |
| 17 | Gotero | `applied_doses.selected_dropper_snapshot` |
| 18 | Observacion | `applied_doses.selected_observation_snapshot` |
| 19 | Fecha de aplicacion | `applied_doses.application_date` |
| 20 | Estado | `applied_doses.status` (`REGISTERED`) |

Notas:

- Se exportan **snapshots** del catalogo (fidelidad historica): el reporte no
  cambia si el catalogo se edita despues.
- Las dosis `CANCELLED` **se excluyen**.
- El "Sexo" se emite en el codigo interno (`MALE`/`FEMALE`); si el formato oficial
  exige etiquetas (`HOMBRE`/`MUJER`), se mapea en una iteracion futura.

---

## 6. Flujo de datos (DIP)

```
ReportController
      │ (actor -> institucion via DataScope)
      ▼
RegistroDiarioExportService (reports)  ── Client del Abstract Factory
      │
      ├── RegistroDiarioQuery (puerto) ──▶ attentions.RegistroDiarioQueryService
      │        (dosis + atencion + patientId; NO accede a pacientes)
      │
      ├── PatientIdentityQuery (puerto) ──▶ patients.PatientIdentityQueryService
      │        (identidad por ids)
      │
      └── ReportFactoryProvider ──▶ PaiReportFactory (XLSX | CSV)
               headerBuilder() + rowWriter() + exporter()
```

- `reports` **no** depende de la persistencia de `attentions` ni de `patients`
  (regla ArchUnit `reports_must_not_depend_on_attentions_persistence`).
- `attentions` **no** depende de `patients` (regla
  `attentions_must_not_depend_on_patients_repositories_or_entities`): obtiene la
  identidad vía el puerto `PatientIdentityQuery` (mismo criterio que
  `PatientScopePolicy`).
- Los puertos viven en `reports` (consumidor) y los implementan los modulos dueños
  del dato (DIP), igual que `ClinicalMetricsQuery`.

---

## 7. Formatos

| Formato | `format` | Content-Type | Extension | Implementacion |
|---|---|---|---|---|
| Excel | `xlsx` | `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` | `.xlsx` | Apache POI (`poi-ooxml`), encabezado en negrita |
| CSV | `csv` | `text/csv; charset=UTF-8` | `.csv` | texto RFC 4180 (comillas si hay coma/comilla/salto), CRLF |

- El **XLSX** se genera con **Apache POI** (dependencia en `pom.xml`).
- El **CSV** no usa dependencias (escape propio en `CsvEncoder`).

---

## 8. Como probar

Tests unitarios:

- `com.pai.api.reports.export.csv.CsvReportExporterTest`
- `com.pai.api.reports.export.xlsx.XlsxReportExporterTest`
- `com.pai.api.reports.export.ReportFactoryProviderTest`

Compilacion y suite:

```powershell
.\mvnw.cmd test
```

Prueba manual (backend local en 8080, con JWT de un vacunador/admin):

```bash
curl -G 'http://localhost:8080/api/v1/reports/registro-diario' \
  --data-urlencode 'from=2026-01-01T00:00:00Z' \
  --data-urlencode 'to=2026-12-31T23:59:59Z' \
  --data-urlencode 'format=xlsx' -H "Authorization: Bearer <JWT>" -o registro.xlsx
```

---

## 9. Extensibilidad

- **Nuevo formato**: agregar un valor a `ReportFormat` y una
  `PaiReportFactory` concreta + sus productos; registrar en `ReportFactoryProvider`.
  El cliente no cambia (Abierto/Cerrado).
- **Nuevo reporte (p. ej. Registro Mensual)**: agregar una nueva familia/columnas
  y su servicio de exportacion reutilizando el Abstract Factory de formatos. El
  diseno actual (columnas via `ReportColumn` + fabricas por formato) permite
  agregarlo sin tocar XLSX/CSV.

---

## 10. Limitaciones actuales

- Solo **Registro Diario** (el Mensual/arqueo quedan para despues).
- El front **no** consume el endpoint todavia.
- El "Sexo" se emite como codigo interno; falta mapear etiquetas oficiales si el
  formato lo exige.
- No hay paginacion: el rango completo se genera en memoria (adecuado para
  volumenes de una institucion; revisar para rangos muy grandes).
