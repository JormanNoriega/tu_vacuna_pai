package com.pai.api.patients.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Dato de contacto de un paciente (telefono, correo u otro). */
@Entity
@Table(name = "patient_contacts", schema = "app")
public class PatientContactEntity {

    public enum Type {
        PHONE,
        EMAIL,
        OTHER
    }

    @Id
    private UUID id;

    @Column(name = "patient_id", nullable = false)
    private UUID patientId;

    @Column(nullable = false)
    private String type;

    @Column(nullable = false)
    private String value;

    @Column(name = "is_primary", nullable = false)
    private boolean primary;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected PatientContactEntity() {}

    public PatientContactEntity(UUID id, UUID patientId, Type type, String value, boolean primary, Instant now) {
        this.id = id;
        this.patientId = patientId;
        this.type = type.name();
        this.value = value;
        this.primary = primary;
        this.createdAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getPatientId() {
        return patientId;
    }

    public String getType() {
        return type;
    }

    public String getValue() {
        return value;
    }

    public boolean isPrimary() {
        return primary;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
