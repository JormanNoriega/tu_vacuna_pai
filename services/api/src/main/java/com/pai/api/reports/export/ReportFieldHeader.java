package com.pai.api.reports.export;

/**
 * Encabezado de campo individual para la fila 1 del reporte.
 *
 * @param name Nombre de la columna (ej. "CONSECUTIVO", "DOSIS", etc.)
 * @param hexColor Color de fondo en formato RGB hexadecimal (ej. "E7E6E6", "B8E7E1", etc.)
 */
public record ReportFieldHeader(String name, String hexColor) {}
