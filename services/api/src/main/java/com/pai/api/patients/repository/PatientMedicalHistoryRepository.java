package com.pai.api.patients.repository;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.pai.api.patients.entity.PatientMedicalHistoryEntity;

public interface PatientMedicalHistoryRepository
        extends JpaRepository<PatientMedicalHistoryEntity, UUID> {

    List<PatientMedicalHistoryEntity> findByPatientIdOrderByCreatedAtAsc(UUID patientId);
}
