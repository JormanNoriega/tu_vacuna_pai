package com.pai.api.attentions.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.pai.api.attentions.entity.AppliedDoseEntity;

/**
 * Acceso a {@link AppliedDoseEntity}. Las dosis son append-only: no se exponen
 * operaciones de actualizacion ni borrado.
 */
public interface AppliedDoseRepository extends JpaRepository<AppliedDoseEntity, UUID> {

    List<AppliedDoseEntity> findByAttentionIdOrderByCreatedAtAsc(UUID attentionId);

    Optional<AppliedDoseEntity> findByIdAndAttentionId(UUID id, UUID attentionId);
}
