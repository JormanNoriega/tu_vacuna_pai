package com.pai.api.patients.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.List;

/** Reemplaza los antecedentes medicos del paciente. */
public record UpdatePatientMedicalHistoriesRequest(
    @Valid List<MedicalHistoryDto> medicalHistories) {

  public record MedicalHistoryDto(
      @NotBlank(message = "El antecedente es obligatorio.")
      @Size(max = 200, message = "El antecedente no puede superar 200 caracteres.")
      String condition,

      LocalDate diagnosedAt,

      @Size(max = 500, message = "Las notas no pueden superar 500 caracteres.")
      String notes,

      Boolean hasContraindication,

      @Size(max = 120, message = "La contraindicacion no puede superar 120 caracteres.")
      String contraindicationDetails,

      Boolean hasPreviousReaction,

      @Size(max = 120, message = "La reaccion no puede superar 120 caracteres.")
      String reactionDetails,

      @Size(max = 60, message = "El tipo de antecedente no puede superar 60 caracteres.")
      String historyType,

      @Size(max = 500, message = "Las observaciones no pueden superar 500 caracteres.")
      String specialObservations) {}
}
