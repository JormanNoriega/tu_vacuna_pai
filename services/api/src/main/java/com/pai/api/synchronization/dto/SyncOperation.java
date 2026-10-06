package com.pai.api.synchronization.dto;

import jakarta.validation.constraints.NotNull;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Comando de dominio transportado por {@code /sync/push} o entregado por
 * {@code /sync/pull}. El transporte concreto esta en
 * {@code docs/api/openapi.yaml} (schemas {@code SyncOperation} y afines); la
 * semantica en {@code docs/synchronization/sync-contract.md}.
 *
 * <p>{@code payload} es el cuerpo especifico del comando y se mapea al DTO del
 * servicio de dominio correspondiente. {@code dependencies} son los
 * {@code operation_id} que deben procesarse antes.
 */
public record SyncOperation(
    @NotNull(message = "El operationId es obligatorio.") UUID operationId,

    @NotNull(message = "El commandType es obligatorio.") String commandType,

    @NotNull(message = "El aggregateId es obligatorio.") UUID aggregateId,

    Map<String, Object> payload,

    List<UUID> dependencies) {}
