package com.pai.api.reports.dto;

/**
 * Resumen de metricas de un rango de fechas para el reporte Registro Diario.
 */
public record RegistroDiarioSummaryResponse(
    long patientsCount,
    long dosesCount,
    long vaccineTypesCount
) {}
