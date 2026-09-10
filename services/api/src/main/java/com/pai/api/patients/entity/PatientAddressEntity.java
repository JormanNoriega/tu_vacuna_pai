package com.pai.api.patients.entity;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/** Direccion de residencia de un paciente. */
@Entity
@Table(name = "patient_addresses", schema = "app")
public class PatientAddressEntity {

    @Id
    private UUID id;

    @Column(name = "patient_id", nullable = false)
    private UUID patientId;

    private String street;

    @Column(name = "municipality_id")
    private UUID municipalityId;

    @Column(name = "department_id")
    private UUID departmentId;

    @Column(name = "country_id")
    private UUID countryId;

    @Column(name = "is_primary", nullable = false)
    private boolean primary;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected PatientAddressEntity() {
    }

    public PatientAddressEntity(UUID id, UUID patientId, String street,
            UUID municipalityId, UUID departmentId, UUID countryId,
            boolean primary, Instant now) {
        this.id = id;
        this.patientId = patientId;
        this.street = street;
        this.municipalityId = municipalityId;
        this.departmentId = departmentId;
        this.countryId = countryId;
        this.primary = primary;
        this.createdAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getPatientId() {
        return patientId;
    }

    public String getStreet() {
        return street;
    }

    public UUID getMunicipalityId() {
        return municipalityId;
    }

    public UUID getDepartmentId() {
        return departmentId;
    }

    public UUID getCountryId() {
        return countryId;
    }

    public boolean isPrimary() {
        return primary;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
