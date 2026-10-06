package com.pai.api.reports.export;

import com.pai.api.reports.export.csv.CsvPaiReportFactory;
import com.pai.api.reports.export.xlsx.XlsxPaiReportFactory;
import java.util.Map;
import java.util.function.Supplier;
import org.springframework.stereotype.Component;

/**
 * Selecciona la {@link PaiReportFactory} concreta segun el formato pedido.
 *
 * <p>Crea una fabrica nueva por exportacion: las fabricas concretas mantienen el
 * buffer de salida (workbook de POI o StringBuilder de CSV) y no deben
 * compartirse entre peticiones.
 */
@Component
public class ReportFactoryProvider {

  private final Map<ReportFormat, Supplier<PaiReportFactory>> factories =
      Map.of(
          ReportFormat.XLSX, XlsxPaiReportFactory::new,
          ReportFormat.CSV, CsvPaiReportFactory::new);

  public PaiReportFactory create(ReportFormat format) {
    Supplier<PaiReportFactory> factory = factories.get(format);
    if (factory == null) {
      throw new IllegalArgumentException("Formato no soportado: " + format);
    }
    return factory.get();
  }
}
