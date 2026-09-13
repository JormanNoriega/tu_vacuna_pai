package com.pai.api.patients.repository;

import com.pai.api.patients.entity.PatientAffiliationEntity;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientAffiliationRepository extends JpaRepository<PatientAffiliationEntity, UUID> {

    Optional<PatientAffiliationEntity> findByPatientId(UUID patientId);
}
