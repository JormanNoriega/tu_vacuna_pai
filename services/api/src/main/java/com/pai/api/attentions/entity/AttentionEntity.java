package com.pai.api.attentions.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
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

    public enum Status {
        DRAFT,
        IN_PROGRESS,
        COMPLETED,
        CANCELLED
    }

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

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Status status;

    private String observations;

    @Column(name = "complete_scheme", nullable = false)
    private boolean completeScheme;

    @Column(name = "paiweb_registered", nullable = false)
    private boolean paiwebRegistered;

    @Column(name = "paiweb_not_registered_reason")
    private String paiwebNotRegisteredReason;

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
        this.status = Status.DRAFT;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public boolean isEditable() {
        return status == Status.DRAFT || status == Status.IN_PROGRESS;
    }

    public boolean acceptsDoses() {
        return status == Status.DRAFT || status == Status.IN_PROGRESS;
    }

    public void updateDetails(Instant attentionDate, String observations, Instant now) {
        this.attentionDate = attentionDate;
        this.observations = observations;
        this.updatedAt = now;
    }

    /** Aplica los datos de registro/cierre: esquema completo y PAIWEB. */
    public void applyRegistrationDetails(
            Boolean completeScheme, Boolean paiwebRegistered, String paiwebNotRegisteredReason, Instant now) {
        if (completeScheme != null) {
            this.completeScheme = completeScheme;
        }
        if (paiwebRegistered != null) {
            this.paiwebRegistered = paiwebRegistered;
        }
        this.paiwebNotRegisteredReason = this.paiwebRegistered ? null : paiwebNotRegisteredReason;
        this.updatedAt = now;
    }

    public void markInProgress(Instant now) {
        this.status = Status.IN_PROGRESS;
        this.updatedAt = now;
    }

    public void complete(Instant now) {
        this.status = Status.COMPLETED;
        this.updatedAt = now;
    }

    public void cancel(Instant now) {
        this.status = Status.CANCELLED;
        this.updatedAt = now;
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

    public Status getStatus() {
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

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
