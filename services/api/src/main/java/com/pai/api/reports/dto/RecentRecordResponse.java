package com.pai.api.reports.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * Resumen de una atencion reciente para la seccion "Ultimos Registros" del dashboard de inicio.
 */
public record RecentRecordResponse(
    UUID id,
    UUID patientId,
    String patientName,
    String vaccineName,
    Instant timestamp) {}
