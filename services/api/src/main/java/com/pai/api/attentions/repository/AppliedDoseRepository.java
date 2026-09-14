package com.pai.api.attentions.repository;

import com.pai.api.attentions.entity.AppliedDoseEntity;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * Acceso a {@link AppliedDoseEntity}. Las dosis son append-only: no se exponen
 * operaciones de actualizacion ni borrado.
 */
public interface AppliedDoseRepository extends JpaRepository<AppliedDoseEntity, UUID> {

  List<AppliedDoseEntity> findByAttentionIdOrderByCreatedAtAsc(UUID attentionId);

  Optional<AppliedDoseEntity> findByIdAndAttentionId(UUID id, UUID attentionId);

  /**
   * Dosis no anuladas de la institucion (via la atencion a la que pertenecen).
   * Alimenta la metrica del home (acumulado historico).
   */
  @Query("""
      SELECT COUNT(d) FROM AppliedDoseEntity d, AttentionEntity a
      WHERE a.id = d.attentionId AND a.institutionId = :institutionId AND d.status <> :excluded
      """)
  long countByInstitutionId(
      @Param("institutionId") UUID institutionId,
      @Param("excluded") AppliedDoseEntity.Status excluded);
}
