package com.pai.api.patients.repository;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.pai.api.patients.entity.PatientGuardianEntity;

public interface PatientGuardianRepository
        extends JpaRepository<PatientGuardianEntity, UUID> {

    List<PatientGuardianEntity> findByPatientIdOrderByCreatedAtAsc(UUID patientId);
}
