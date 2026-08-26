package com.pai.api.identity.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

public record UpdateInstitutionConfigRequest(
        @NotNull(message = "La ventana offline es obligatoria.")
        @Min(value = 1, message = "La ventana offline debe ser mayor a 0.")
        @Max(value = 168, message = "La ventana offline no puede superar 168 horas.")
        Short offlineWindowHours) {
}