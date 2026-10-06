package com.pai.api.reports.export.csv;

import com.pai.api.reports.export.PaiReportFactory;
import com.pai.api.reports.export.ReportExporter;
import com.pai.api.reports.export.ReportHeaderBuilder;
import com.pai.api.reports.export.ReportRowWriter;

/**
 * ConcreteFactory: familia de productos CSV. Los tres productos comparten el
 * mismo {@link StringBuilder} (el "sink" del formato).
 */
public final class CsvPaiReportFactory implements PaiReportFactory {

  private final StringBuilder out = new StringBuilder();

  @Override
  public ReportHeaderBuilder headerBuilder() {
    return new CsvReportHeaderBuilder(out);
  }

  @Override
  public ReportRowWriter rowWriter() {
    return new CsvReportRowWriter(out);
  }

  @Override
  public ReportExporter exporter() {
    return new CsvReportExporter(out);
  }
}
