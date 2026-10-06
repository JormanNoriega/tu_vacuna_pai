package com.pai.api.reports.export.csv;

import com.pai.api.reports.export.ReportRowWriter;
import java.util.List;
import java.util.stream.Collectors;

/** ConcreteProduct: una fila CSV (linea de celdas separadas por coma). */
final class CsvReportRowWriter implements ReportRowWriter {

  private static final String LINE_SEPARATOR = "\r\n";

  private final StringBuilder out;

  CsvReportRowWriter(StringBuilder out) {
    this.out = out;
  }

  @Override
  public void writeRow(List<String> cells) {
    out.append(cells.stream().map(CsvEncoder::field).collect(Collectors.joining(",")))
        .append(LINE_SEPARATOR);
  }
}
