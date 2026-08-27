package com.pai.api.identity.entity;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Registro de una operacion de aprovisionamiento de identidad. Ver
 * {@link ProvisioningOperationStatus} para la maquina de estados.
 */
@Entity
@Table(name = "provisioning_operations", schema = "app")
public class ProvisioningOperationEntity {

    @Id
    @Column(name = "operation_id", nullable = false)
    private UUID operationId;

    @Column(name = "auth_user_id")
    private UUID authUserId;

    @Column(nullable = false)
    private String email;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(name = "institution_id", nullable = false)
    private UUID institutionId;

    @Column(nullable = false)
    private String role;

    @Column(name = "actor_id", nullable = false)
    private UUID actorId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ProvisioningOperationStatus status;

    @Column(nullable = false)
    private short attempts;

    @Column(columnDefinition = "text")
    private String error;

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

    protected ProvisioningOperationEntity() {
    }

    public ProvisioningOperationEntity(UUID operationId, UUID authUserId, String email,
            String fullName, UUID institutionId, String role, UUID actorId,
            ProvisioningOperationStatus status, short attempts, String error,
            Instant createdAt, Instant updatedAt) {
        this(operationId, authUserId, email, fullName, institutionId, role, actorId,
            status, attempts, error, createdAt, updatedAt,
            null, null, null, null, null, null, null, null);
    }

    public ProvisioningOperationEntity(UUID operationId, UUID authUserId, String email,
            String fullName, UUID institutionId, String role, UUID actorId,
            ProvisioningOperationStatus status, short attempts, String error,
            Instant createdAt, Instant updatedAt,
            String documentType, String documentNumber, String phone,
            LocalDate birthDate, String gender, String professionCode,
            String professionalRegistrationNumber, String professionalRegistrationType) {
        this.operationId = operationId;
        this.authUserId = authUserId;
        this.email = email;
        this.fullName = fullName;
        this.institutionId = institutionId;
        this.role = role;
        this.actorId = actorId;
        this.status = status;
        this.attempts = attempts;
        this.error = error;
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

    public UUID getOperationId() {
        return operationId;
    }

    public UUID getAuthUserId() {
        return authUserId;
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

    public String getRole() {
        return role;
    }

    public UUID getActorId() {
        return actorId;
    }

    public ProvisioningOperationStatus getStatus() {
        return status;
    }

    public short getAttempts() {
        return attempts;
    }

    public String getError() {
        return error;
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

    public void setAuthUserId(UUID authUserId) {
        this.authUserId = authUserId;
    }

    public void setStatus(ProvisioningOperationStatus status) {
        this.status = status;
    }

    public void setAttempts(short attempts) {
        this.attempts = attempts;
    }

    public void setError(String error) {
        this.error = error;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }
}