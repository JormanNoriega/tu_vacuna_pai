package com.pai.api.identity.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "users", schema = "app")
public class UserEntity {

    public enum Status {
        ACTIVE,
        INACTIVE
    }

    @Id
    private UUID id;

    @Column(nullable = false)
    private String email;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(name = "institution_id", nullable = false)
    private UUID institutionId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Status status;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "document_type")
    private String documentType;

    @Column(name = "document_number")
    private String documentNumber;

    private String phone;

    @Column(name = "birth_date")
    private LocalDate birthDate;

    private String gender;

    @Column(name = "profession_code")
    private String professionCode;

    @Column(name = "professional_registration_number")
    private String professionalRegistrationNumber;

    @Column(name = "professional_registration_type")
    private String professionalRegistrationType;

    protected UserEntity() {}

    public UserEntity(
            UUID id,
            String email,
            String fullName,
            UUID institutionId,
            Status status,
            Instant createdAt,
            Instant updatedAt) {
        this(
                id,
                email,
                fullName,
                institutionId,
                status,
                createdAt,
                updatedAt,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null);
    }

    public UserEntity(
            UUID id,
            String email,
            String fullName,
            UUID institutionId,
            Status status,
            Instant createdAt,
            Instant updatedAt,
            String documentType,
            String documentNumber,
            String phone,
            LocalDate birthDate,
            String gender,
            String professionCode,
            String professionalRegistrationNumber,
            String professionalRegistrationType) {
        this.id = id;
        this.email = email;
        this.fullName = fullName;
        this.institutionId = institutionId;
        this.status = status;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        this.documentType = documentType;
        this.documentNumber = documentNumber;
        this.phone = phone;
        this.birthDate = birthDate;
        this.gender = gender;
        this.professionCode = professionCode;
        this.professionalRegistrationNumber = professionalRegistrationNumber;
        this.professionalRegistrationType = professionalRegistrationType;
    }

    public boolean isActive() {
        return status == Status.ACTIVE;
    }

    public void setStatus(Status status) {
        this.status = status;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }

    public UUID getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getFullName() {
        return fullName;
    }

    public UUID getInstitutionId() {
        return institutionId;
    }

    public Status getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
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

    public LocalDate getBirthDate() {
        return birthDate;
    }

    public String getGender() {
        return gender;
    }

    public String getProfessionCode() {
        return professionCode;
    }

    public String getProfessionalRegistrationNumber() {
        return professionalRegistrationNumber;
    }

    public String getProfessionalRegistrationType() {
        return professionalRegistrationType;
    }
}
