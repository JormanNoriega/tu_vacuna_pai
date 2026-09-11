package com.pai.api.patients.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.time.LocalDate;
import java.util.List;

/** Reemplaza los antecedentes medicos del paciente. */
public record UpdatePatientMedicalHistoriesRequest(@Valid List<MedicalHistoryDto> medicalHistories) {

    public record MedicalHistoryDto(
            @NotBlank(message = "El antecedente es obligatorio.")
            String condition,

            LocalDate diagnosedAt,
            String notes) {}
}
