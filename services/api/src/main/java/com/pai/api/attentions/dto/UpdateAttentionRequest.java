package com.pai.api.attentions.dto;

import jakarta.validation.constraints.Size;
import java.time.Instant;

/**
 * Modificacion de una atencion. Solo permitida en {@code DRAFT}/
 * {@code IN_PROGRESS}. {@code version} habilita el bloqueo optimista: si otro
 * usuario la modifico, el servicio responde {@code 409}.
 */
public record UpdateAttentionRequest(
        Instant attentionDate,

        @Size(max = 2000, message = "Las observaciones no pueden superar 2000 caracteres.")
        String observations,

        Boolean completeScheme,

        Boolean paiwebRegistered,

        @Size(max = 500, message = "El motivo de no ingreso no puede superar 500 caracteres.")
        String paiwebNotRegisteredReason,

        long version) {}
