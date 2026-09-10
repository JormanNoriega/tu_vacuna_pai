package com.pai.api.attentions.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.pai.api.attentions.entity.AttentionEntity;

/**
 * Acceso a {@link AttentionEntity}. Regla de alcance: las atenciones se leen y
 * modifican SIEMPRE con criterio de institucion (equivalente a RLS en la capa
 * de datos).
 */
public interface AttentionRepository extends JpaRepository<AttentionEntity, UUID> {

    Optional<AttentionEntity> findByIdAndInstitutionId(UUID id, UUID institutionId);

    List<AttentionEntity> findByInstitutionIdAndPatientIdOrderByAttentionDateDesc(
            UUID institutionId, UUID patientId);

    /**
     * Ultimo consecutivo de la institucion. El servicio le suma uno para el
     * siguiente. Es una aproximacion sin bloqueo; la unicidad real se refuerza
     * con la clave de negocio de la atencion.
     */
    @Query("""
        SELECT COALESCE(MAX(a.consecutive), 0) FROM AttentionEntity a
        WHERE a.institutionId = :institutionId
        """)
    long maxConsecutive(@Param("institutionId") UUID institutionId);
}
