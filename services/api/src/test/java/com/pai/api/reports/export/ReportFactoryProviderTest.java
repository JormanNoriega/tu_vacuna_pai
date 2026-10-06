package com.pai.api.reports.export;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.pai.api.reports.export.csv.CsvPaiReportFactory;
import com.pai.api.reports.export.xlsx.XlsxPaiReportFactory;
import org.junit.jupiter.api.Test;

class ReportFactoryProviderTest {

  private final ReportFactoryProvider provider = new ReportFactoryProvider();

  @Test
  void createsTheConcreteFactoryForEachFormat() {
    assertThat(provider.create(ReportFormat.XLSX)).isInstanceOf(XlsxPaiReportFactory.class);
    assertThat(provider.create(ReportFormat.CSV)).isInstanceOf(CsvPaiReportFactory.class);
  }

  @Test
  void parsesFormatIgnoringCaseAndDefaultsToXlsx() {
    assertThat(ReportFormat.from("CSV")).isEqualTo(ReportFormat.CSV);
    assertThat(ReportFormat.from("Xlsx")).isEqualTo(ReportFormat.XLSX);
    assertThat(ReportFormat.from(null)).isEqualTo(ReportFormat.XLSX);
    assertThat(ReportFormat.from(" ")).isEqualTo(ReportFormat.XLSX);
    assertThatThrownBy(() -> ReportFormat.from("pdf")).isInstanceOf(IllegalArgumentException.class);
  }
}
