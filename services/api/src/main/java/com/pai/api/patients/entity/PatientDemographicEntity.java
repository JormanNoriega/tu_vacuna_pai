package com.pai.api.patients.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * Datos demograficos del paciente (1:1). {@code gender} es un dato
 * demografico, distinto de {@code Patient.sex} (sexo biologico para reglas
 * clinicas). El id es el mismo {@code patient_id}.
 */
@Entity
@Table(name = "patient_demographics", schema = "app")
public class PatientDemographicEntity {

    @Id
    @Column(name = "patient_id")
    private UUID patientId;

    private String gender;

    private String ethnicity;

    @Column(name = "sexual_orientation")
    private String sexualOrientation;

    @Column(name = "education_level")
    private String educationLevel;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected PatientDemographicEntity() {}

    public PatientDemographicEntity(
            UUID patientId, String gender, String ethnicity, String educationLevel, Instant now) {
        this(patientId, gender, ethnicity, null, educationLevel, now);
    }

    public PatientDemographicEntity(
            UUID patientId,
            String gender,
            String ethnicity,
            String sexualOrientation,
            String educationLevel,
            Instant now) {
        this.patientId = patientId;
        this.gender = gender;
        this.ethnicity = ethnicity;
        this.sexualOrientation = sexualOrientation;
        this.educationLevel = educationLevel;
        this.updatedAt = now;
    }

    public UUID getPatientId() {
        return patientId;
    }

    public String getGender() {
        return gender;
    }

    public String getEthnicity() {
        return ethnicity;
    }

    public String getSexualOrientation() {
        return sexualOrientation;
    }

    public String getEducationLevel() {
        return educationLevel;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
