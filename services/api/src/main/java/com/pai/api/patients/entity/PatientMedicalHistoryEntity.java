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

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected PatientMedicalHistoryEntity() {}

    public PatientMedicalHistoryEntity(
            UUID id, UUID patientId, String condition, LocalDate diagnosedAt, String notes, Instant now) {
        this.id = id;
        this.patientId = patientId;
        this.condition = condition;
        this.diagnosedAt = diagnosedAt;
        this.notes = notes;
        this.createdAt = now;
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
