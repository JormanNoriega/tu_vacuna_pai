package com.pai.api.reports.export.xlsx;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.ByteArrayInputStream;
import java.util.List;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;

class XlsxReportExporterTest {

  @Test
  void exportsHeaderAndRowsAsWorkbook() throws Exception {
    XlsxPaiReportFactory factory = new XlsxPaiReportFactory();
    factory.headerBuilder().writeHeader(List.of("A", "B"));
    factory.rowWriter().writeRow(List.of("1", "2"));

    byte[] bytes = factory.exporter().export();

    assertThat(bytes).isNotEmpty();
    try (Workbook workbook = new XSSFWorkbook(new ByteArrayInputStream(bytes))) {
      Sheet sheet = workbook.getSheetAt(0);
      assertThat(sheet.getRow(0).getCell(0).getStringCellValue()).isEqualTo("A");
      assertThat(sheet.getRow(0).getCell(1).getStringCellValue()).isEqualTo("B");
      assertThat(sheet.getRow(1).getCell(0).getStringCellValue()).isEqualTo("1");
      assertThat(sheet.getRow(1).getCell(1).getStringCellValue()).isEqualTo("2");
    }
  }
}
