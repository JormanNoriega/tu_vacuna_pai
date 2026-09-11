package com.pai.api.synchronization.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

/**
 * Registro de idempotencia de un comando clinico (D3). Guarda la respuesta
 * original para que un reenvio con el mismo {@code operation_id} devuelva el
 * resultado original sin reprocesar.
 *
 * <p>La columna {@code sync_sequence} (BIGSERIAL) la asigna la base y no se
 * mapea aqui: es el cursor monotono del pull y se expone por consulta nativa
 * cuando el modulo de sincronizacion lo necesite.
 */
@Entity
@Table(name = "processed_operations", schema = "app")
public class ProcessedOperationEntity {

    @Id
    @Column(name = "operation_id")
    private UUID operationId;

    @Column(name = "command_type", nullable = false)
    private String commandType;

    @Column(name = "aggregate_id")
    private UUID aggregateId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "response_payload", nullable = false)
    private String responsePayload;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected ProcessedOperationEntity() {}

    public ProcessedOperationEntity(
            UUID operationId, String commandType, UUID aggregateId, String responsePayload, Instant now) {
        this.operationId = operationId;
        this.commandType = commandType;
        this.aggregateId = aggregateId;
        this.responsePayload = responsePayload;
        this.createdAt = now;
    }

    public UUID getOperationId() {
        return operationId;
    }

    public String getCommandType() {
        return commandType;
    }

    public UUID getAggregateId() {
        return aggregateId;
    }

    public String getResponsePayload() {
        return responsePayload;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
