package com.pai.api.patients.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** Antecedente medico de un paciente. */
@Entity
@Table(name = "patient_medical_histories", schema = "app")
public class PatientMedicalHistoryEntity {

    @Id
    private UUID id;

    @Column(name = "patient_id", nullable = false)
    private UUID patientId;

    @Column(nullable = false)
    private String condition;

    @Column(name = "diagnosed_at")
    private LocalDate diagnosedAt;

    private String notes;

    @Column(name = "has_contraindication", nullable = false)
    private boolean hasContraindication;

    @Column(name = "contraindication_details")
    private String contraindicationDetails;

    @Column(name = "has_previous_reaction", nullable = false)
    private boolean hasPreviousReaction;

    @Column(name = "reaction_details")
    private String reactionDetails;

    @Column(name = "history_type")
    private String historyType;

    @Column(name = "special_observations")
    private String specialObservations;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected PatientMedicalHistoryEntity() {}

    public PatientMedicalHistoryEntity(
            UUID id, UUID patientId, String condition, LocalDate diagnosedAt, String notes, Instant now) {
        this(id, patientId, condition, diagnosedAt, notes, false, null, false, null, null, null, now);
    }

    public PatientMedicalHistoryEntity(
            UUID id,
            UUID patientId,
            String condition,
            LocalDate diagnosedAt,
            String notes,
            boolean hasContraindication,
            String contraindicationDetails,
            boolean hasPreviousReaction,
            String reactionDetails,
            String historyType,
            String specialObservations,
            Instant now) {
        this.id = id;
        this.patientId = patientId;
        this.condition = condition;
        this.diagnosedAt = diagnosedAt;
        this.notes = notes;
        this.hasContraindication = hasContraindication;
        this.contraindicationDetails = contraindicationDetails;
        this.hasPreviousReaction = hasPreviousReaction;
        this.reactionDetails = reactionDetails;
        this.historyType = historyType;
        this.specialObservations = specialObservations;
        this.createdAt = now;
    }

    public boolean isHasContraindication() {
        return hasContraindication;
    }

    public String getContraindicationDetails() {
        return contraindicationDetails;
    }

    public boolean isHasPreviousReaction() {
        return hasPreviousReaction;
    }

    public String getReactionDetails() {
        return reactionDetails;
    }

    public String getHistoryType() {
        return historyType;
    }

    public String getSpecialObservations() {
        return specialObservations;
    }

    public UUID getId() {
        return id;
    }

    public UUID getPatientId() {
        return patientId;
    }

    public String getCondition() {
        return condition;
    }

    public LocalDate getDiagnosedAt() {
        return diagnosedAt;
    }

    public String getNotes() {
        return notes;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
