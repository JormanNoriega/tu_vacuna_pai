package com.pai.api.reports.export.xlsx;

import com.pai.api.reports.export.ReportExporter;

/** ConcreteProduct: serializa el workbook XLSX a bytes. */
final class XlsxReportExporter implements ReportExporter {

  private final XlsxReportSurface surface;

  XlsxReportExporter(XlsxReportSurface surface) {
    this.surface = surface;
  }

  @Override
  public byte[] export() {
    return surface.toBytes();
  }
}
