package com.pai.api.identity.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateInstitutionRequest(
    @NotBlank(message = "El codigo de la institucion es obligatorio.")
    @Size(max = 32, message = "El codigo no puede superar 32 caracteres.")
    String code,

    @NotBlank(message = "El nombre de la institucion es obligatorio.")
    @Size(max = 200, message = "El nombre no puede superar 200 caracteres.")
    String name,

    @Min(value = 1, message = "La ventana offline debe ser mayor a 0.")
    @Max(value = 168, message = "La ventana offline no puede superar 168 horas.")
    Short offlineWindowHours) {}
