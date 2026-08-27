package com.pai.api.identity.dto;

import java.time.Instant;
import java.util.UUID;

import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.ProvisioningOperationStatus;

/**
 * Vista de auditoria de una operacion de aprovisionamiento: quien, cuando, que
 * institucion, que rol, y el resultado (incluido el de una compensacion).
 */
public record ProvisioningOperationResponse(
        UUID operationId,
        UUID authUserId,
        String email,
        String fullName,
        UUID institutionId,
        String role,
        UUID actorId,
        ProvisioningOperationStatus status,
        short attempts,
        String error,
        Instant createdAt,
        Instant updatedAt) {

    public static ProvisioningOperationResponse from(ProvisioningOperationEntity entity) {
        return new ProvisioningOperationResponse(
            entity.getOperationId(),
            entity.getAuthUserId(),
            entity.getEmail(),
            entity.getFullName(),
            entity.getInstitutionId(),
            entity.getRole(),
            entity.getActorId(),
            entity.getStatus(),
            entity.getAttempts(),
            entity.getError(),
            entity.getCreatedAt(),
            entity.getUpdatedAt());
    }
}