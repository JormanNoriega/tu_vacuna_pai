package com.pai.api.reports.export.xlsx;

import com.pai.api.reports.export.ReportCategoryBlock;
import com.pai.api.reports.export.ReportCategoryColors;
import com.pai.api.reports.export.ReportFieldHeader;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.apache.poi.ss.usermodel.BorderStyle;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.FillPatternType;
import org.apache.poi.ss.usermodel.HorizontalAlignment;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.VerticalAlignment;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.xssf.usermodel.XSSFCellStyle;
import org.apache.poi.xssf.usermodel.XSSFColor;
import org.apache.poi.xssf.usermodel.XSSFFont;
import org.apache.poi.xssf.usermodel.XSSFSheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

/**
 * Sink compartido de la familia XLSX: workbook + hoja + estilo de encabezado +
 * cursor de fila. Los tres productos concretos escriben sobre esta misma
 * superficie.
 */
final class XlsxReportSurface {

  private static final String SHEET_NAME = "Sheet1";
  private static final XSSFColor BORDER_COLOR =
      new XSSFColor(new byte[] {(byte) 0xD9, (byte) 0xD9, (byte) 0xD9}, null);

  private final XSSFWorkbook workbook = new XSSFWorkbook();
  private final XSSFSheet sheet = workbook.createSheet(SHEET_NAME);
  private final CellStyle simpleHeaderStyle;
  private final CellStyle evenRowStyle;
  private final CellStyle oddRowStyle;
  private final Map<String, CellStyle> categoryStyles = new HashMap<>();
  private final Map<String, CellStyle> subheaderStyles = new HashMap<>();
  private int rowCursor = 0;
  private int totalColumns = 0;

  XlsxReportSurface() {
    this.sheet.setDisplayGridlines(true);
    this.sheet.setPrintGridlines(true);
    this.simpleHeaderStyle = createSimpleHeaderStyle();
    this.evenRowStyle = createRowStyle(ReportCategoryColors.ROW_EVEN);
    this.oddRowStyle = createRowStyle(ReportCategoryColors.ROW_ODD);
  }

  void writeHeaderRow(List<String> titles) {
    Row row = sheet.createRow(rowCursor++);
    totalColumns = Math.max(totalColumns, titles.size());
    for (int column = 0; column < titles.size(); column++) {
      Cell cell = row.createCell(column);
      String title = titles.get(column);
      cell.setCellValue(title);
      cell.setCellStyle(simpleHeaderStyle);

      int charCount = title != null ? title.trim().length() : 0;
      int width = Math.max(charCount + 3, 6);
      sheet.setColumnWidth(column, width * 256);
    }
  }

  void writeDualLevelHeader(
      List<ReportCategoryBlock> categories, List<ReportFieldHeader> fields) {
    Row row0 = sheet.createRow(0);

    int colIndex = 0;
    for (ReportCategoryBlock category : categories) {
      int span = category.columnSpan();
      CellStyle catStyle = getCategoryStyle(category.hexColor());

      for (int i = 0; i < span; i++) {
        Cell cell = row0.createCell(colIndex + i);
        if (i == 0) {
          cell.setCellValue(category.name());
        }
        cell.setCellStyle(catStyle);
      }

      if (span > 1) {
        sheet.addMergedRegion(
            new CellRangeAddress(0, 0, colIndex, colIndex + span - 1));
      }
      colIndex += span;
    }

    Row row1 = sheet.createRow(1);

    for (int i = 0; i < fields.size(); i++) {
      ReportFieldHeader field = fields.get(i);
      Cell cell = row1.createCell(i);
      cell.setCellValue(field.name());
      cell.setCellStyle(getSubheaderStyle(field.hexColor()));

      String name = field.name();
      int charCount = name != null ? name.trim().length() : 0;
      int width = Math.max(charCount + 3, 6);
      sheet.setColumnWidth(i, width * 256);
    }

    totalColumns = Math.max(colIndex, fields.size());
    sheet.createFreezePane(0, 2);
    rowCursor = 2;
  }

  void writeDataRow(List<String> cells) {
    Row row = sheet.createRow(rowCursor);
    CellStyle style = (rowCursor % 2 == 0) ? evenRowStyle : oddRowStyle;
    rowCursor++;

    totalColumns = Math.max(totalColumns, cells.size());
    for (int column = 0; column < cells.size(); column++) {
      Cell cell = row.createCell(column);
      String value = cells.get(column);
      cell.setCellValue(value == null ? "" : value);
      cell.setCellStyle(style);
    }
  }

  byte[] toBytes() {
    try (ByteArrayOutputStream out = new ByteArrayOutputStream();
        XSSFWorkbook wb = this.workbook) {
      wb.write(out);
      return out.toByteArray();
    } catch (IOException ex) {
      throw new IllegalStateException("No se pudo generar el archivo XLSX.", ex);
    }
  }

  private CellStyle createSimpleHeaderStyle() {
    XSSFCellStyle style = workbook.createCellStyle();
    XSSFFont font = workbook.createFont();
    font.setFontName("Arial");
    font.setFontHeightInPoints((short) 10);
    font.setBold(true);
    style.setFont(font);
    style.setAlignment(HorizontalAlignment.LEFT);
    style.setVerticalAlignment(VerticalAlignment.CENTER);
    applyBorders(style);
    return style;
  }

  private CellStyle getCategoryStyle(String hexColor) {
    return categoryStyles.computeIfAbsent(
        hexColor,
        hex -> {
          XSSFCellStyle style = workbook.createCellStyle();
          XSSFColor bg = parseColor(hex);
          style.setFillForegroundColor(bg);
          style.setFillPattern(FillPatternType.SOLID_FOREGROUND);

          XSSFFont font = workbook.createFont();
          font.setFontName("Arial");
          font.setBold(true);
          font.setColor(
              new XSSFColor(
                  new byte[] {(byte) 0xFF, (byte) 0xFF, (byte) 0xFF}, null));
          font.setFontHeightInPoints((short) 10);
          style.setFont(font);

          style.setAlignment(HorizontalAlignment.LEFT);
          style.setVerticalAlignment(VerticalAlignment.CENTER);
          applyBorders(style);
          return style;
        });
  }

  private CellStyle getSubheaderStyle(String hexColor) {
    return subheaderStyles.computeIfAbsent(
        hexColor,
        hex -> {
          XSSFCellStyle style = workbook.createCellStyle();
          XSSFColor bg = parseColor(hex);
          style.setFillForegroundColor(bg);
          style.setFillPattern(FillPatternType.SOLID_FOREGROUND);

          XSSFFont font = workbook.createFont();
          font.setFontName("Arial");
          font.setBold(true);
          font.setFontHeightInPoints((short) 10);
          style.setFont(font);

          style.setAlignment(HorizontalAlignment.LEFT);
          style.setVerticalAlignment(VerticalAlignment.CENTER);
          style.setWrapText(false);
          applyBorders(style);
          return style;
        });
  }

  private CellStyle createRowStyle(String hexColor) {
    XSSFCellStyle style = workbook.createCellStyle();
    XSSFColor bg = parseColor(hexColor);
    style.setFillForegroundColor(bg);
    style.setFillPattern(FillPatternType.SOLID_FOREGROUND);

    XSSFFont font = workbook.createFont();
    font.setFontName("Arial");
    font.setFontHeightInPoints((short) 10);
    style.setFont(font);

    style.setAlignment(HorizontalAlignment.LEFT);
    style.setVerticalAlignment(VerticalAlignment.CENTER);
    applyBorders(style);
    return style;
  }

  private void applyBorders(XSSFCellStyle style) {
    style.setBorderTop(BorderStyle.THIN);
    style.setTopBorderColor(BORDER_COLOR);
    style.setBorderBottom(BorderStyle.THIN);
    style.setBottomBorderColor(BORDER_COLOR);
    style.setBorderLeft(BorderStyle.THIN);
    style.setLeftBorderColor(BORDER_COLOR);
    style.setBorderRight(BorderStyle.THIN);
    style.setRightBorderColor(BORDER_COLOR);
  }

  private static XSSFColor parseColor(String hex) {
    if (hex == null || hex.isBlank()) {
      return new XSSFColor(
          new byte[] {(byte) 0xFF, (byte) 0xFF, (byte) 0xFF}, null);
    }
    String clean = hex.replace("#", "").trim();
    if (clean.length() == 8) {
      clean = clean.substring(2);
    }
    if (clean.length() < 6) {
      return new XSSFColor(
          new byte[] {(byte) 0xFF, (byte) 0xFF, (byte) 0xFF}, null);
    }
    int r = Integer.parseInt(clean.substring(0, 2), 16);
    int g = Integer.parseInt(clean.substring(2, 4), 16);
    int b = Integer.parseInt(clean.substring(4, 6), 16);
    return new XSSFColor(new byte[] {(byte) r, (byte) g, (byte) b}, null);
  }
}
