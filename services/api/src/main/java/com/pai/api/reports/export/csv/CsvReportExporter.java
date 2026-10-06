package com.pai.api.reports.export.csv;

import com.pai.api.reports.export.ReportExporter;
import java.nio.charset.StandardCharsets;

/** ConcreteProduct: serializa el contenido CSV acumulado a bytes UTF-8. */
final class CsvReportExporter implements ReportExporter {

  private final StringBuilder out;

  CsvReportExporter(StringBuilder out) {
    this.out = out;
  }

  @Override
  public byte[] export() {
    return out.toString().getBytes(StandardCharsets.UTF_8);
  }
}
