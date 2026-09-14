package com.pai.api.attentions.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Anulacion de una atencion. El motivo es obligatorio (invariante de dominio). */
public record CancelAttentionRequest(
    @NotBlank(message = "El motivo de anulacion es obligatorio.")
    @Size(min = 5, max = 500, message = "El motivo debe tener entre 5 y 500 caracteres.")
    String reason) {}
