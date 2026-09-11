package com.pai.api.attentions.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

/**
 * Creacion de una atencion (nace en {@code DRAFT}). El profesional y la
 * institucion se derivan del actor; el cliente solo indica el paciente y,
 * opcionalmente, la fecha y observaciones.
 */
public record CreateAttentionRequest(
        @NotNull(message = "El paciente es obligatorio.") UUID patientId,

        Instant attentionDate,

        @Size(max = 2000, message = "Las observaciones no pueden superar 2000 caracteres.")
        String observations) {}
