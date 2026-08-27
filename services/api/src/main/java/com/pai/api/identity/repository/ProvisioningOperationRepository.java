package com.pai.api.identity.repository;

import java.time.Instant;
import java.util.Collection;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.ProvisioningOperationStatus;

/**
 * Acceso a {@link ProvisioningOperationEntity}. Las transiciones de estado se
 * ejecutan con guarda sobre el estado previo ({@code WHERE status = :expected}),
 * de modo que un reintento o un request concurrente nunca pisan un estado que
 * ya avanzo.
 */
public interface ProvisioningOperationRepository
        extends JpaRepository<ProvisioningOperationEntity, UUID> {

    /**
     * Transicion de estado con guarda. Devuelve 1 si el estado previo coincidia
     * con {@code expectedStatus}; 0 si ya avanzo (concurrencia).
     */
    @Modifying
    @Transactional
    @Query("""
        UPDATE ProvisioningOperationEntity o
        SET o.status = :status, o.updatedAt = :updatedAt,
            o.authUserId = :authUserId, o.error = :error
        WHERE o.operationId = :operationId AND o.status = :expectedStatus
        """)
    int transition(
            @Param("operationId") UUID operationId,
            @Param("expectedStatus") ProvisioningOperationStatus expectedStatus,
            @Param("status") ProvisioningOperationStatus status,
            @Param("authUserId") UUID authUserId,
            @Param("error") String error,
            @Param("updatedAt") Instant updatedAt);

    /**
     * Registra el auth.user creado y avanza a {@code AUTH_CREATED} desde
     * cualquier estado previo que aun no tenga auth.user ({@code PENDING} o
     * {@code UNCERTAIN}). Devuelve 0 si la operacion ya avanzo.
     */
    @Modifying
    @Transactional
    @Query("""
        UPDATE ProvisioningOperationEntity o
        SET o.status = 'AUTH_CREATED', o.authUserId = :authUserId,
            o.updatedAt = :updatedAt, o.error = NULL
        WHERE o.operationId = :operationId AND o.status IN :allowedFrom
        """)
    int adoptAuthUser(@Param("operationId") UUID operationId,
            @Param("allowedFrom") Collection<ProvisioningOperationStatus> allowedFrom,
            @Param("authUserId") UUID authUserId,
            @Param("updatedAt") Instant updatedAt);

    /**
     * Marca la operacion como completada. Acepta cualquier estado previo que
     * implique un auth.user existente sin espejo; devuelve 0 si ya esta en un
     * estado terminal (p. ej. COMPLETED).
     */
    @Modifying
    @Transactional
    @Query("""
        UPDATE ProvisioningOperationEntity o
        SET o.status = 'COMPLETED', o.updatedAt = :updatedAt
        WHERE o.operationId = :operationId AND o.status IN :allowedFrom
        """)
    int markCompleted(@Param("operationId") UUID operationId,
            @Param("allowedFrom") Collection<ProvisioningOperationStatus> allowedFrom,
            @Param("updatedAt") Instant updatedAt);
}