package com.pai.api.patients.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Paciente registrado por una institucion. El identificador es un UUID
 * generado por el servidor; la identidad de negocio es el par
 * {@code (institution_id, document_type, document_number)}.
 *
 * <p>La entidad es plana a proposito: las tablas hijas (contactos,
 * demografia, direcciones, tutores y antecedentes) se gestionan con sus
 * propios repositorios, igual que {@code UserRoleEntity} en identity. No se
 * usan asociaciones JPA para mantener el mapeo explicito y verificable.
 */
@Entity
@Table(name = "patients", schema = "app")
public class PatientEntity {

    public enum Sex {
        MALE,
        FEMALE
    }

    public enum Status {
        ACTIVE,
        INACTIVE
    }

    @Id
    private UUID id;

    @Column(name = "institution_id", nullable = false)
    private UUID institutionId;

    @Column(name = "document_type", nullable = false)
    private String documentType;

    @Column(name = "document_number", nullable = false)
    private String documentNumber;

    @Column(name = "first_name", nullable = false)
    private String firstName;

    @Column(name = "last_name", nullable = false)
    private String lastName;

    @Column(name = "birth_date", nullable = false)
    private LocalDate birthDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Sex sex;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Status status;

    @Version
    private long version;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected PatientEntity() {}

    public PatientEntity(
            UUID id,
            UUID institutionId,
            String documentType,
            String documentNumber,
            String firstName,
            String lastName,
            LocalDate birthDate,
            Sex sex,
            Instant now) {
        this.id = id;
        this.institutionId = institutionId;
        this.documentType = documentType;
        this.documentNumber = documentNumber;
        this.firstName = firstName;
        this.lastName = lastName;
        this.birthDate = birthDate;
        this.sex = sex;
        this.status = Status.ACTIVE;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public void updateIdentity(String firstName, String lastName, LocalDate birthDate, Sex sex, Instant now) {
        this.firstName = firstName;
        this.lastName = lastName;
        this.birthDate = birthDate;
        this.sex = sex;
        this.updatedAt = now;
    }

    public void setStatus(Status status, Instant now) {
        this.status = status;
        this.updatedAt = now;
    }

    public boolean isActive() {
        return status == Status.ACTIVE;
    }

    public UUID getId() {
        return id;
    }

    public UUID getInstitutionId() {
        return institutionId;
    }

    public String getDocumentType() {
        return documentType;
    }

    public String getDocumentNumber() {
        return documentNumber;
    }

    public String getFirstName() {
        return firstName;
    }

    public String getLastName() {
        return lastName;
    }

    public LocalDate getBirthDate() {
        return birthDate;
    }

    public Sex getSex() {
        return sex;
    }

    public Status getStatus() {
        return status;
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
