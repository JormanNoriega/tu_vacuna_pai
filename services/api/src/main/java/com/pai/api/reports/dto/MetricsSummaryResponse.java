package com.pai.api.reports.dto;

/**
 * Resumen de metricas de la institucion para el home del vacunador y del
 * administrador. Los valores son acumulados historicos.
 */
public record MetricsSummaryResponse(long patientsAttended, long dosesApplied) {}
