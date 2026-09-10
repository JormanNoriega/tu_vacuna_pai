package com.pai.api.attentions.dto;

import java.time.Instant;
import java.util.UUID;

import jakarta.validation.constraints.NotNull;

/**
 * Creacion de una atencion (nace en {@code DRAFT}). El profesional y la
 * institucion se derivan del actor; el cliente solo indica el paciente y,
 * opcionalmente, la fecha y observaciones.
 */
public record CreateAttentionRequest(
        @NotNull(message = "El paciente es obligatorio.")
        UUID patientId,

        Instant attentionDate,

        String observations) {
}
