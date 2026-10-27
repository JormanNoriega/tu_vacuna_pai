package com.pai.api.attentions.dto;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/**
 * Estado Extrinseco (no compartido) de una aplicacion particular de dosis.
 * Varia por cada paciente, frasco utilizado y momento en que se aplica la vacuna.
 */
public record DoseExtrinsicContext(
    UUID doseId,
    UUID patientId,
    String patientDocument,
    String lotNumber,
    Instant applicationDate,
    String doseLabel,
    String healthWorker) {

  public DoseExtrinsicContext {
    Objects.requireNonNull(patientId, "patientId no puede ser nulo");
    Objects.requireNonNull(applicationDate, "applicationDate no puede ser nulo");
    doseLabel = (doseLabel == null || doseLabel.isBlank()) ? "Dosis Estandar" : doseLabel;
    lotNumber = (lotNumber == null || lotNumber.isBlank()) ? "SIN_LOTE" : lotNumber;
    patientDocument = (patientDocument == null || patientDocument.isBlank()) ? "N/D" : patientDocument;
    healthWorker = (healthWorker == null || healthWorker.isBlank()) ? "Personal PAI" : healthWorker;
  }
}
