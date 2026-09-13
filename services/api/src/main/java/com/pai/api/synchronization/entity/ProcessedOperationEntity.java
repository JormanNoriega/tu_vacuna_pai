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
 * <p>Ademas es la fuente del pull: {@code sync_sequence} (BIGSERIAL) es el cursor
 * monotono, {@code institution_id} el scope y {@code payload} el cuerpo original
 * del request (necesario para reconstruir el {@code SyncOperation} que aplica el
 * cliente). La columna {@code sync_sequence} la asigna la base, por lo que no es
 * insertable ni actualizable desde JPA.
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

    @Column(name = "institution_id")
    private UUID institutionId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "payload", nullable = false)
    private String payload;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "response_payload", nullable = false)
    private String responsePayload;

    @Column(name = "sync_sequence", insertable = false, updatable = false)
    private Long syncSequence;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected ProcessedOperationEntity() {}

    public ProcessedOperationEntity(
            UUID operationId,
            String commandType,
            UUID aggregateId,
            UUID institutionId,
            String payload,
            String responsePayload,
            Instant now) {
        this.operationId = operationId;
        this.commandType = commandType;
        this.aggregateId = aggregateId;
        this.institutionId = institutionId;
        this.payload = payload;
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

    public UUID getInstitutionId() {
        return institutionId;
    }

    public String getPayload() {
        return payload;
    }

    public String getResponsePayload() {
        return responsePayload;
    }

    public Long getSyncSequence() {
        return syncSequence;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
