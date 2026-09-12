package com.pai.api.patients.repository;

import com.pai.api.patients.entity.PatientUserConditionEntity;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientUserConditionRepository extends JpaRepository<PatientUserConditionEntity, UUID> {

    Optional<PatientUserConditionEntity> findByPatientId(UUID patientId);
}
