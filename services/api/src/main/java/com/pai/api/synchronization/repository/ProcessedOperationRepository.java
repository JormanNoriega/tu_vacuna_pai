package com.pai.api.synchronization.repository;

import com.pai.api.synchronization.entity.ProcessedOperationEntity;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProcessedOperationRepository extends JpaRepository<ProcessedOperationEntity, UUID> {

    /**
     * Operaciones de una institucion con {@code sync_sequence} estrictamente
     * mayor al cursor, ordenadas de forma ascendente. El cliente deduplica por
     * {@code operation_id} como red de seguridad (cursor inclusivo sobre
     * {@code sync_sequence}, no sobre {@code created_at}).
     */
    List<ProcessedOperationEntity> findByInstitutionIdAndSyncSequenceGreaterThanOrderBySyncSequenceAsc(
            UUID institutionId, long syncSequence, Pageable pageable);
}
