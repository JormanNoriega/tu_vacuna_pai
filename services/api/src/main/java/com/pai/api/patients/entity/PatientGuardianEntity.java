package com.pai.api.patients.entity;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** Tutor o responsable de un paciente (madre, padre, cuidador u otro). */
@Entity
@Table(name = "patient_guardians", schema = "app")
public class PatientGuardianEntity {

    public enum Relationship { MOTHER, FATHER, CAREGIVER, OTHER }

    @Id
    private UUID id;

    @Column(name = "patient_id", nullable = false)
    private UUID patientId;

    @Column(nullable = false)
    private String relationship;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(name = "document_type")
    private String documentType;

    @Column(name = "document_number")
    private String documentNumber;

    private String phone;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected PatientGuardianEntity() {
    }

    public PatientGuardianEntity(UUID id, UUID patientId, Relationship relationship,
            String fullName, String documentType, String documentNumber,
            String phone, Instant now) {
        this.id = id;
        this.patientId = patientId;
        this.relationship = relationship.name();
        this.fullName = fullName;
        this.documentType = documentType;
        this.documentNumber = documentNumber;
        this.phone = phone;
        this.createdAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getPatientId() {
        return patientId;
    }

    public String getRelationship() {
        return relationship;
    }

    public String getFullName() {
        return fullName;
    }

    public String getDocumentType() {
        return documentType;
    }

    public String getDocumentNumber() {
        return documentNumber;
    }

    public String getPhone() {
        return phone;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
