package com.pai.api.attentions.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

/**
 * Creacion de una atencion (nace en {@code DRAFT}). El profesional y la
 * institucion se derivan del actor; el cliente solo indica el paciente y,
 * opcionalmente, la fecha, observaciones y coordenadas geograficas.
 */
public record CreateAttentionRequest(
    @NotNull(message = "El paciente es obligatorio.") UUID patientId,

    Instant attentionDate,

    @Size(max = 2000, message = "Las observaciones no pueden superar 2000 caracteres.")
    String observations,

    Boolean completeScheme,

    Boolean paiwebRegistered,

    @Size(max = 500, message = "El motivo de no ingreso no puede superar 500 caracteres.")
    String paiwebNotRegisteredReason,

    @DecimalMin(value = "-90.0", message = "La latitud no puede ser menor a -90.0.")
    @DecimalMax(value = "90.0", message = "La latitud no puede superar 90.0.")
    Double latitude,

    @DecimalMin(value = "-180.0", message = "La longitud no puede ser menor a -180.0.")
    @DecimalMax(value = "180.0", message = "La longitud no puede superar 180.0.")
    Double longitude) {}
