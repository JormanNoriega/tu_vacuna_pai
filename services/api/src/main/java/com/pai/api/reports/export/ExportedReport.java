package com.pai.api.reports.export;

/** Resultado de exportar un reporte: contenido binario + metadatos HTTP. */
public record ExportedReport(byte[] content, String filename, String contentType) {}
