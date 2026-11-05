package com.pai.api.reports.export;

/**
 * Bloque de categoria superior para la fila 0 del reporte Excel.
 *
 * @param name Nombre de la categoria (ej. "DATOS BÁSICOS", "VACUNAS", etc.)
 * @param columnSpan Cantidad de columnas que abarca
 * @param hexColor Color de fondo en formato RGB hexadecimal (ej. "4472C4")
 */
public record ReportCategoryBlock(String name, int columnSpan, String hexColor) {}
