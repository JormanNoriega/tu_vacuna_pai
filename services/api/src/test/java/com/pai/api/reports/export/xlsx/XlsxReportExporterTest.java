package com.pai.api.reports.export.xlsx;

import static org.assertj.core.api.Assertions.assertThat;

import com.pai.api.reports.export.ReportCategoryBlock;
import com.pai.api.reports.export.ReportCategoryColors;
import com.pai.api.reports.export.ReportFieldHeader;
import java.io.ByteArrayInputStream;
import java.util.List;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.HorizontalAlignment;
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

  @Test
  void exportsDualLevelCategorizedHeaderAndZebraRows() throws Exception {
    XlsxPaiReportFactory factory = new XlsxPaiReportFactory();

    List<ReportCategoryBlock> categories =
        List.of(
            new ReportCategoryBlock("DATOS BÁSICOS", 2, ReportCategoryColors.BASIC_DATA),
            new ReportCategoryBlock("DATOS ENFERMERA", 1, ReportCategoryColors.NURSE_DATA));

    List<ReportFieldHeader> fields =
        List.of(
            new ReportFieldHeader("CONSECUTIVO", ReportCategoryColors.HEADER_ROW),
            new ReportFieldHeader("PRIMER NOMBRE", ReportCategoryColors.HEADER_ROW),
            new ReportFieldHeader("NOMBRE ENFERMERA", ReportCategoryColors.NURSE_FIELD));

    factory.headerBuilder().writeCategoryHeader(categories, fields);
    factory.rowWriter().writeRow(List.of("001", "CARLOS", "ANA LÓPEZ"));
    factory.rowWriter().writeRow(List.of("002", "MARÍA", "ANA LÓPEZ"));

    byte[] bytes = factory.exporter().export();

    assertThat(bytes).isNotEmpty();
    try (Workbook workbook = new XSSFWorkbook(new ByteArrayInputStream(bytes))) {
      Sheet sheet = workbook.getSheetAt(0);

      // Fila 0: Categorias combinadas
      assertThat(sheet.getRow(0).getCell(0).getStringCellValue()).isEqualTo("DATOS BÁSICOS");
      assertThat(sheet.getRow(0).getCell(2).getStringCellValue()).isEqualTo("DATOS ENFERMERA");
      assertThat(sheet.getNumMergedRegions()).isEqualTo(1);
      assertThat(sheet.getMergedRegion(0).formatAsString()).isEqualTo("A1:B1");

      Font catFont = workbook.getFontAt(sheet.getRow(0).getCell(0).getCellStyle().getFontIndex());
      assertThat(catFont.getFontName()).isEqualTo("Arial");
      assertThat(catFont.getFontHeightInPoints()).isEqualTo((short) 10);
      assertThat(catFont.getBold()).isTrue();
      assertThat(sheet.getRow(0).getCell(0).getCellStyle().getAlignment())
          .isEqualTo(HorizontalAlignment.LEFT);

      // Fila 1: Subencabezados
      assertThat(sheet.getRow(1).getCell(0).getStringCellValue()).isEqualTo("CONSECUTIVO");
      assertThat(sheet.getRow(1).getCell(1).getStringCellValue()).isEqualTo("PRIMER NOMBRE");
      assertThat(sheet.getRow(1).getCell(2).getStringCellValue()).isEqualTo("NOMBRE ENFERMERA");

      Font subFont = workbook.getFontAt(sheet.getRow(1).getCell(0).getCellStyle().getFontIndex());
      assertThat(subFont.getFontName()).isEqualTo("Arial");
      assertThat(subFont.getFontHeightInPoints()).isEqualTo((short) 10);
      assertThat(subFont.getBold()).isTrue();
      assertThat(sheet.getRow(1).getCell(0).getCellStyle().getAlignment())
          .isEqualTo(HorizontalAlignment.LEFT);

      // Fila 2 y 3: Datos
      assertThat(sheet.getRow(2).getCell(0).getStringCellValue()).isEqualTo("001");
      assertThat(sheet.getRow(2).getCell(1).getStringCellValue()).isEqualTo("CARLOS");
      assertThat(sheet.getRow(3).getCell(0).getStringCellValue()).isEqualTo("002");
      assertThat(sheet.getRow(3).getCell(1).getStringCellValue()).isEqualTo("MARÍA");

      Font dataFont = workbook.getFontAt(sheet.getRow(2).getCell(0).getCellStyle().getFontIndex());
      assertThat(dataFont.getFontName()).isEqualTo("Arial");
      assertThat(dataFont.getFontHeightInPoints()).isEqualTo((short) 10);
      assertThat(sheet.getRow(2).getCell(0).getCellStyle().getAlignment())
          .isEqualTo(HorizontalAlignment.LEFT);

      // Altura estandar y compacta en todas las filas (igual que las filas de datos, sin formatos altos)
      assertThat(sheet.getRow(0).getHeight()).isEqualTo(sheet.getDefaultRowHeight());
      assertThat(sheet.getRow(1).getHeight()).isEqualTo(sheet.getDefaultRowHeight());
      assertThat(sheet.getRow(2).getHeight()).isEqualTo(sheet.getDefaultRowHeight());
      assertThat(sheet.getRow(3).getHeight()).isEqualTo(sheet.getDefaultRowHeight());

      // Ancho de columnas ajustado al texto del encabezado sin estirarse de más
      assertThat(sheet.getColumnWidth(0)).isEqualTo(14 * 256);
      assertThat(sheet.getColumnWidth(1)).isEqualTo(16 * 256);
      assertThat(sheet.getColumnWidth(2)).isEqualTo(19 * 256);
    }
  }
}
