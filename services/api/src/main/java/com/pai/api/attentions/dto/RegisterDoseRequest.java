package com.pai.api.attentions.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

/**
 * Registro de una dosis aplicada (append-only). El backend toma el snapshot del
 * catalogo vigente: nombre/codigo de la vacuna, etiqueta de dosis, tipo de
 * neumococo y las opciones operativas elegidas de la institucion.
 *
 * <p>{@code lotId} quedara referenciado al inventario cuando exista; por ahora
 * se guarda {@code lotNumber} (texto).
 */
public record RegisterDoseRequest(
        @NotNull(message = "La vacuna es obligatoria.") UUID vaccineId,

        @NotNull(message = "La dosis es obligatoria.") UUID doseOptionId,

        UUID pneumococcalTypeOptionId,

        Instant applicationDate,

        UUID lotId,

        @Size(max = 60, message = "El lote no puede superar 60 caracteres.")
        String lotNumber,

        UUID selectedLaboratoryId,

        UUID selectedSyringeId,

        UUID selectedDropperId,

        UUID selectedObservationId,

        @Size(max = 60, message = "El lote de jeringa no puede superar 60 caracteres.")
        String syringeLot,

        @Size(max = 120, message = "El diluyente no puede superar 120 caracteres.")
        String diluent,

        Integer vialCount,

        @Size(max = 500, message = "La observacion no puede superar 500 caracteres.")
        String customObservation) {}
