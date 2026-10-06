package com.pai.api.reports.domain;

import java.time.Instant;
import java.time.LocalDate;

/**
 * Fila del reporte "Registro Diario" PAI: una dosis aplicada con los datos de su
 * paciente y de la atencion.
 *
 * <p>Es el dato comun e independiente del formato de salida; el Abstract Factory
 * lo convierte a XLSX o CSV. El orden de los campos no define el del reporte: el
 * orden de columnas lo fija {@code RegistroDiarioExportService}.
 */
public record RegistroDiarioRow(
    Long consecutive,
    Instant attentionDate,
    String documentType,
    String documentNumber,
    String firstName,
    String secondName,
    String lastName,
    String secondLastName,
    LocalDate birthDate,
    String sex,
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
