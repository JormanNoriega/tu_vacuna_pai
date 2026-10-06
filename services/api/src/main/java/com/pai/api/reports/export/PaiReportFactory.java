package com.pai.api.reports.export;

/**
 * AbstractFactory del patron: crea la familia de productos de salida de un
 * reporte —encabezado, filas y exportador— para un formato concreto. Las
 * fabricas concretas ({@code XlsxPaiReportFactory}, {@code CsvPaiReportFactory})
 * comparten un mismo buffer de salida entre los tres productos.
 */
public interface PaiReportFactory {

  ReportHeaderBuilder headerBuilder();

  ReportRowWriter rowWriter();

  ReportExporter exporter();
}
