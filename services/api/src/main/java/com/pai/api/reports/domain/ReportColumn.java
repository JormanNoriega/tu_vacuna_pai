package com.pai.api.reports.domain;

import java.util.function.Function;

/** Columna del reporte: titulo visible + como extraer su valor de una fila. */
public record ReportColumn(String title, Function<RegistroDiarioRow, String> value) {}
