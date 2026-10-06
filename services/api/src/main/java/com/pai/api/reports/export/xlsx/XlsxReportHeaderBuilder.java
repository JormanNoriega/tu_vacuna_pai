package com.pai.api.reports.export.xlsx;

import com.pai.api.reports.export.ReportHeaderBuilder;
import java.util.List;

/** ConcreteProduct: encabezado XLSX (fila con celdas en negrita). */
final class XlsxReportHeaderBuilder implements ReportHeaderBuilder {

  private final XlsxReportSurface surface;

  XlsxReportHeaderBuilder(XlsxReportSurface surface) {
    this.surface = surface;
  }

  @Override
  public void writeHeader(List<String> titles) {
    surface.writeHeaderRow(titles);
  }
}
