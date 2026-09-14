package com.pai.api.audit.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

/**
 * Evento de auditoria de una operacion sensible. Se escribe en la misma
 * transaccion que la operacion de negocio. {@code payload} guarda el detalle
 * relevante (valores, motivo de anulacion, diff) como JSON.
 */
@Entity
@Table(name = "audit_events", schema = "app")
public class AuditEventEntity {

  @Id
  private UUID id;

  @Column(name = "actor_id", nullable = false)
  private UUID actorId;

  @Column(name = "institution_id", nullable = false)
  private UUID institutionId;

  @Column(nullable = false)
  private String action;

  @Column(name = "resource_type", nullable = false)
  private String resourceType;

  @Column(name = "resource_id", nullable = false)
  private UUID resourceId;

  @Column(name = "client_operation_id")
  private UUID clientOperationId;

  @JdbcTypeCode(SqlTypes.JSON)
  @Column(nullable = false)
  private String payload;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  protected AuditEventEntity() {}

  public AuditEventEntity(
      UUID id,
      UUID actorId,
      UUID institutionId,
      String action,
      String resourceType,
      UUID resourceId,
      UUID clientOperationId,
      String payload,
      Instant now) {
    this.id = id;
    this.actorId = actorId;
    this.institutionId = institutionId;
    this.action = action;
    this.resourceType = resourceType;
    this.resourceId = resourceId;
    this.clientOperationId = clientOperationId;
    this.payload = payload;
    this.createdAt = now;
  }

  public UUID getId() {
    return id;
  }

  public UUID getActorId() {
    return actorId;
  }

  public UUID getInstitutionId() {
    return institutionId;
  }

  public String getAction() {
    return action;
  }

  public String getResourceType() {
    return resourceType;
  }

  public UUID getResourceId() {
    return resourceId;
  }

  public UUID getClientOperationId() {
    return clientOperationId;
  }

  public String getPayload() {
    return payload;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }
}
