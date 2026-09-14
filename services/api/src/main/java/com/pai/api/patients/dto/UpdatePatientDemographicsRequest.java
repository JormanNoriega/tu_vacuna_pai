package com.pai.api.patients.dto;

import jakarta.validation.constraints.Size;

/** Actualiza los datos demograficos del paciente (1:1). */
public record UpdatePatientDemographicsRequest(
    @Size(max = 20, message = "El genero no puede superar 20 caracteres.")
    String gender,

    @Size(max = 80, message = "La etnia no puede superar 80 caracteres.")
    String ethnicity,

    @Size(max = 120, message = "La escolaridad no puede superar 120 caracteres.")
    String educationLevel) {}
