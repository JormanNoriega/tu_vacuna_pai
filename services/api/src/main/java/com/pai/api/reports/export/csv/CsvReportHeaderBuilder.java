package com.pai.api.reports.export.csv;

import com.pai.api.reports.export.ReportHeaderBuilder;
import java.util.List;
import java.util.stream.Collectors;

/** ConcreteProduct: encabezado CSV (una linea de titulos). */
final class CsvReportHeaderBuilder implements ReportHeaderBuilder {

  private static final String LINE_SEPARATOR = "\r\n";

  private final StringBuilder out;

  CsvReportHeaderBuilder(StringBuilder out) {
    this.out = out;
  }

  @Override
  public void writeHeader(List<String> titles) {
    out.append(titles.stream().map(CsvEncoder::field).collect(Collectors.joining(",")))
        .append(LINE_SEPARATOR);
  }
}
