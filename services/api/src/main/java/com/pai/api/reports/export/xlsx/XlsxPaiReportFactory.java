package com.pai.api.reports.export.xlsx;

import com.pai.api.reports.export.PaiReportFactory;
import com.pai.api.reports.export.ReportExporter;
import com.pai.api.reports.export.ReportHeaderBuilder;
import com.pai.api.reports.export.ReportRowWriter;

/**
 * ConcreteFactory: familia de productos XLSX (Office Open XML). Los tres
 * productos comparten el mismo {@link XlsxReportSurface} (workbook + hoja).
 */
public final class XlsxPaiReportFactory implements PaiReportFactory {

  private final XlsxReportSurface surface = new XlsxReportSurface();

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
