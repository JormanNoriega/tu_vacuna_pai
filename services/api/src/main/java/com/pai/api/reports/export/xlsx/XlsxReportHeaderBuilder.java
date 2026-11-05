package com.pai.api.reports.export.xlsx;

import com.pai.api.reports.export.ReportCategoryBlock;
import com.pai.api.reports.export.ReportFieldHeader;
import com.pai.api.reports.export.ReportHeaderBuilder;
import java.util.List;

/** ConcreteProduct: encabezado XLSX (fila simple o doble nivel categorizado). */
final class XlsxReportHeaderBuilder implements ReportHeaderBuilder {

  private final XlsxReportSurface surface;

  XlsxReportHeaderBuilder(XlsxReportSurface surface) {
    this.surface = surface;
  }

  @Override
  public void writeHeader(List<String> titles) {
    surface.writeHeaderRow(titles);
  }

  @Override
  public void writeCategoryHeader(
      List<ReportCategoryBlock> categories, List<ReportFieldHeader> fields) {
    surface.writeDualLevelHeader(categories, fields);
  }
}
