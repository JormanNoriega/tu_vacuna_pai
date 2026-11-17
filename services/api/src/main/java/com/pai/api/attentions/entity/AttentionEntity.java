package com.pai.api.attentions.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import com.pai.api.attentions.exception.InvalidClinicalStateException;
import com.pai.api.attentions.state.AttentionState;
import com.pai.api.attentions.state.DraftState;
import jakarta.persistence.Convert;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/**
 * Agregado raiz de la atencion de vacunacion. Es mutable solo en
 * {@code DRAFT}/{@code IN_PROGRESS}; al pasar a {@code COMPLETED} queda
 * inmutable (solo se anula con motivo). Las dosis aplicadas viven en
 * {@link AppliedDoseEntity} y son append-only.
 */
@Entity
@Table(name = "attentions", schema = "app")
public class AttentionEntity {

  @Id
  private UUID id;

  @Column(name = "patient_id", nullable = false)
  private UUID patientId;

  @Column(name = "professional_id", nullable = false)
  private UUID professionalId;

  @Column(name = "institution_id", nullable = false)
  private UUID institutionId;

  @Column(name = "attention_date", nullable = false)
  private Instant attentionDate;

  private Long consecutive;

  @Column(name = "client_operation_id")
  private UUID clientOperationId;

  @Convert(converter = AttentionStateConverter.class)
  @Column(nullable = false)
  private AttentionState status;

  private String observations;

  @Column(name = "complete_scheme", nullable = false)
  private boolean completeScheme;

  @Column(name = "paiweb_registered", nullable = false)
  private boolean paiwebRegistered;

  @Column(name = "paiweb_not_registered_reason")
  private String paiwebNotRegisteredReason;

  @Column(name = "latitude")
  private Double latitude;

  @Column(name = "longitude")
  private Double longitude;

  @Version
  private long version;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  protected AttentionEntity() {}

  public AttentionEntity(
      UUID id,
      UUID patientId,
      UUID professionalId,
      UUID institutionId,
      Instant attentionDate,
      Long consecutive,
      UUID clientOperationId,
      Instant now) {
    this.id = id;
    this.patientId = patientId;
    this.professionalId = professionalId;
    this.institutionId = institutionId;
    this.attentionDate = attentionDate;
    this.consecutive = consecutive;
    this.clientOperationId = clientOperationId;
    this.status = DraftState.INSTANCE;
    this.createdAt = now;
    this.updatedAt = now;
  }

  public boolean isEditable() {
    return status.isEditable();
  }

  public boolean acceptsDoses() {
    return status.acceptsDoses();
  }

  public void updateDetails(Instant attentionDate, String observations, Instant now) {
    requireEditable();
    this.attentionDate = attentionDate;
    this.observations = observations;
    this.updatedAt = now;
  }

  /** Aplica los datos de registro/cierre: esquema completo y PAIWEB. */
  public void applyRegistrationDetails(
      Boolean completeScheme,
      Boolean paiwebRegistered,
      String paiwebNotRegisteredReason,
      Instant now) {
    requireEditable();
    if (completeScheme != null) {
      this.completeScheme = completeScheme;
    }
    if (paiwebRegistered != null) {
      this.paiwebRegistered = paiwebRegistered;
    }
    this.paiwebNotRegisteredReason = this.paiwebRegistered ? null : paiwebNotRegisteredReason;
    this.updatedAt = now;
  }

  public void complete(Instant now) {
    setState(status.complete(), now);
  }

  public void cancel(Instant now) {
    setState(status.cancel(), now);
  }

  private void setState(AttentionState nextState, Instant now) {
    Objects.requireNonNull(nextState, "nextState");
    Objects.requireNonNull(now, "now");
    this.status = nextState;
    this.updatedAt = now;
  }

  private void requireEditable() {
    if (!isEditable()) {
      throw new InvalidClinicalStateException("La atencion no se puede modificar en su estado actual.");
    }
  }

  public UUID getId() {
    return id;
  }

  public UUID getPatientId() {
    return patientId;
  }

  public UUID getProfessionalId() {
    return professionalId;
  }

  public UUID getInstitutionId() {
    return institutionId;
  }

  public Instant getAttentionDate() {
    return attentionDate;
  }

  public Long getConsecutive() {
    return consecutive;
  }

  public UUID getClientOperationId() {
    return clientOperationId;
  }

  public AttentionState getStatus() {
    return status;
  }

  public String getObservations() {
    return observations;
  }

  public boolean isCompleteScheme() {
    return completeScheme;
  }

  public boolean isPaiwebRegistered() {
    return paiwebRegistered;
  }

  public String getPaiwebNotRegisteredReason() {
    return paiwebNotRegisteredReason;
  }

  public long getVersion() {
    return version;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }

  public Double getLatitude() {
    return latitude;
  }

  public Double getLongitude() {
    return longitude;
  }

  public void setLocation(Double latitude, Double longitude) {
    requireEditable();
    this.latitude = latitude;
    this.longitude = longitude;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }
}
