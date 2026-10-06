package com.pai.api.reports.export.csv;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.util.List;
import org.junit.jupiter.api.Test;

class CsvReportExporterTest {

  @Test
  void exportsHeaderAndRowsAsCsvWithRfc4180Escaping() {
    CsvPaiReportFactory factory = new CsvPaiReportFactory();
    factory.headerBuilder().writeHeader(List.of("A", "B"));
    factory.rowWriter().writeRow(List.of("1", "2"));
    factory.rowWriter().writeRow(List.of("x,y", "he said \"hi\""));

    String csv = new String(factory.exporter().export(), StandardCharsets.UTF_8);

    assertThat(csv).isEqualTo("A,B\r\n1,2\r\n\"x,y\",\"he said \"\"hi\"\"\"\r\n");
  }
}
