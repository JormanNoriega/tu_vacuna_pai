package com.pai.api.reports.export.xlsx;

import com.pai.api.reports.export.ReportRowWriter;
import java.util.List;

/** ConcreteProduct: fila de datos XLSX. */
final class XlsxReportRowWriter implements ReportRowWriter {

  private final XlsxReportSurface surface;

  XlsxReportRowWriter(XlsxReportSurface surface) {
    this.surface = surface;
  }

  @Override
  public void writeRow(List<String> cells) {
    surface.writeDataRow(cells);
  }
}
