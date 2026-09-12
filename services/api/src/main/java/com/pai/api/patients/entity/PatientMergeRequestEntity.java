package com.pai.api.patients.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * Solicitud de fusion de identidad de paciente (D6/D11). Se crea cuando un
 * intento de alta choca con el indice unico {@code (institution, documentType,
 * documentNumber)}: la operacion se rechaza con {@code DUPLICATE_BUSINESS_IDENTITY}
 * y queda pendiente de revision online por {@code ADMIN_INSTITUTION}.
 *
 * <p>El paciente nuevo no llega a persistirse, por lo que
 * {@code duplicatePatientId} apunta al paciente existente y
 * {@code canonicalPatientId} queda nulo hasta la resolucion.
 */
@Entity
@Table(name = "patient_merge_requests", schema = "app")
public class PatientMergeRequestEntity {

    public enum Status {
        PENDING_REVIEW,
        RESOLVED,
        REJECTED
    }

    @Id
    private UUID id;

    @Column(name = "duplicate_patient_id", nullable = false)
    private UUID duplicatePatientId;

    @Column(name = "canonical_patient_id")
    private UUID canonicalPatientId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Status status;

    @Column(name = "resolved_by")
    private UUID resolvedBy;

    @Column(name = "resolved_at")
    private Instant resolvedAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected PatientMergeRequestEntity() {}

    public PatientMergeRequestEntity(UUID id, UUID duplicatePatientId, Status status, Instant createdAt) {
        this.id = id;
        this.duplicatePatientId = duplicatePatientId;
        this.status = status;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getDuplicatePatientId() {
        return duplicatePatientId;
    }

    public UUID getCanonicalPatientId() {
        return canonicalPatientId;
    }

    public Status getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
