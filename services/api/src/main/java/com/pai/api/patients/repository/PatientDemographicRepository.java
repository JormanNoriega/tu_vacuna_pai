package com.pai.api.patients.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.pai.api.patients.entity.PatientDemographicEntity;

public interface PatientDemographicRepository
        extends JpaRepository<PatientDemographicEntity, UUID> {

    Optional<PatientDemographicEntity> findByPatientId(UUID patientId);
}
