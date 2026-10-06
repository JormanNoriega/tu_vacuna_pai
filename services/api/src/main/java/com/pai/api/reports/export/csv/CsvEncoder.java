package com.pai.api.reports.export.csv;

/** Codificacion de un campo CSV (RFC 4180): comillas si contiene coma, comilla o salto. */
final class CsvEncoder {

  private CsvEncoder() {}

  static String field(String value) {
    if (value == null) {
      return "";
    }
    boolean needsQuotes =
        value.indexOf(',') >= 0
            || value.indexOf('"') >= 0
            || value.indexOf('\n') >= 0
            || value.indexOf('\r') >= 0;
    if (!needsQuotes) {
      return value;
    }
    return "\"" + value.replace("\"", "\"\"") + "\"";
  }
}
