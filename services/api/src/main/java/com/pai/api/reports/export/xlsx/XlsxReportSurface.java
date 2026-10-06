package com.pai.api.reports.export.xlsx;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.List;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

/**
 * Sink compartido de la familia XLSX: workbook + hoja + estilo de encabezado +
 * cursor de fila. Los tres productos concretos escriben sobre esta misma
 * superficie.
 */
final class XlsxReportSurface {

  private static final String SHEET_NAME = "Registro Diario";

  private final Workbook workbook = new XSSFWorkbook();
  private final Sheet sheet = workbook.createSheet(SHEET_NAME);
  private final CellStyle headerStyle;
  private int rowCursor = 0;

  XlsxReportSurface() {
    this.headerStyle = workbook.createCellStyle();
    Font font = workbook.createFont();
    font.setBold(true);
    headerStyle.setFont(font);
  }

  void writeHeaderRow(List<String> titles) {
    Row row = sheet.createRow(rowCursor++);
    for (int column = 0; column < titles.size(); column++) {
      Cell cell = row.createCell(column);
      cell.setCellValue(titles.get(column));
      cell.setCellStyle(headerStyle);
    }
  }

  void writeDataRow(List<String> cells) {
    Row row = sheet.createRow(rowCursor++);
    for (int column = 0; column < cells.size(); column++) {
      Cell cell = row.createCell(column);
      String value = cells.get(column);
      cell.setCellValue(value == null ? "" : value);
    }
  }

  byte[] toBytes() {
    try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
      workbook.write(out);
      workbook.close();
      return out.toByteArray();
    } catch (IOException ex) {
      throw new IllegalStateException("No se pudo generar el archivo XLSX.", ex);
    }
  }
}
