package com.pai.api.reports.export;

/**
 * Formatos de salida soportados por el exportador de reportes PAI. Cada valor
 * aporta su content-type HTTP y la extension del archivo generado.
 */
public enum ReportFormat {
  XLSX("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "xlsx"),
  CSV("text/csv; charset=UTF-8", "csv");

  private final String contentType;
  private final String extension;

  ReportFormat(String contentType, String extension) {
    this.contentType = contentType;
    this.extension = extension;
  }

  public String contentType() {
    return contentType;
  }

  public String extension() {
    return extension;
  }

  /** Convierte el parametro de request (p. ej. "xlsx"/"csv") al enum. */
  public static ReportFormat from(String value) {
    if (value == null || value.isBlank()) {
      return XLSX;
    }
    try {
      return ReportFormat.valueOf(value.trim().toUpperCase());
    } catch (IllegalArgumentException ex) {
      throw new IllegalArgumentException("Formato no soportado: " + value + ". Usa xlsx o csv.");
    }
  }
}
