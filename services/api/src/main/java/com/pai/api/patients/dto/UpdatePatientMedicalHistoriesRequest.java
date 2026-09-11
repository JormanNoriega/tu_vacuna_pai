package com.pai.api.patients.dto;

import java.time.LocalDate;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

/** Reemplaza los antecedentes medicos del paciente. */
public record UpdatePatientMedicalHistoriesRequest(
        @Valid List<MedicalHistoryDto> medicalHistories) {

    public record MedicalHistoryDto(
            @NotBlank(message = "El antecedente es obligatorio.") String condition,
            LocalDate diagnosedAt,
            String notes) {
    }
}
