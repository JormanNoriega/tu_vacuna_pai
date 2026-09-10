package com.pai.api.patients.repository;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.pai.api.patients.entity.PatientContactEntity;

public interface PatientContactRepository
        extends JpaRepository<PatientContactEntity, UUID> {

    List<PatientContactEntity> findByPatientIdOrderByCreatedAtAsc(UUID patientId);

    void deleteByPatientId(UUID patientId);
}
