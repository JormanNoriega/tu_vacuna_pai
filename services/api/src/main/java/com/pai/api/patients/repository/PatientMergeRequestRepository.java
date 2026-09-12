package com.pai.api.patients.repository;

import com.pai.api.patients.entity.PatientMergeRequestEntity;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientMergeRequestRepository extends JpaRepository<PatientMergeRequestEntity, UUID> {

    boolean existsByDuplicatePatientIdAndStatus(UUID duplicatePatientId, PatientMergeRequestEntity.Status status);
}
