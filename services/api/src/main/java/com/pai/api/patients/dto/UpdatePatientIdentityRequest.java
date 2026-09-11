package com.pai.api.patients.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

/**
 * Actualiza la identidad del paciente (nombres, fecha de nacimiento y sexo).
 * Exige una justificacion: el cambio de identidad es una operacion sensible y
 * queda auditada.
 */
public record UpdatePatientIdentityRequest(
        @NotBlank(message = "El nombre es obligatorio.")
        @Size(max = 120, message = "El nombre no puede superar 120 caracteres.")
        String firstName,

        @NotBlank(message = "El apellido es obligatorio.")
        @Size(max = 120, message = "El apellido no puede superar 120 caracteres.")
        String lastName,

        @NotNull(message = "La fecha de nacimiento es obligatoria.")
        LocalDate birthDate,

        @NotBlank(message = "El sexo es obligatorio.") String sex,

        @NotBlank(message = "La justificacion es obligatoria.")
        @Size(min = 5, max = 500, message = "La justificacion debe tener entre 5 y 500 caracteres.")
        String justification) {}
