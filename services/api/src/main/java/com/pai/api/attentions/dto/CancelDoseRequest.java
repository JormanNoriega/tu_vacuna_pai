package com.pai.api.attentions.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Anulacion de una dosis aplicada. El motivo es obligatorio (append-only). */
public record CancelDoseRequest(
        @NotBlank(message = "El motivo de anulacion es obligatorio.")
        @Size(min = 5, max = 500, message = "El motivo debe tener entre 5 y 500 caracteres.")
        String reason) {}
