package com.pai.api.reports.domain;

import java.time.Instant;
import java.util.UUID;

/**
 * Dosis aplicada (con su atencion) para el reporte "Registro Diario". Lo produce
 * el modulo {@code attentions} a traves del puerto {@code RegistroDiarioQuery};
 * incluye el {@code patientId} para que {@code reports} cruce la identidad.
 */
public record RegistroDiarioDoseData(
    Long consecutive,
    Instant attentionDate,
    UUID patientId,
    String vaccineName,
    String vaccineCode,
    String doseLabel,
    String lotNumber,
    String laboratory,
    String syringe,
    String dropper,
    String observation,
    Instant applicationDate,
    String status) {}
