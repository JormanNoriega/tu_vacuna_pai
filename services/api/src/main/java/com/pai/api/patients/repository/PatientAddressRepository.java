package com.pai.api.patients.repository;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.pai.api.patients.entity.PatientAddressEntity;

public interface PatientAddressRepository
        extends JpaRepository<PatientAddressEntity, UUID> {

    List<PatientAddressEntity> findByPatientIdOrderByCreatedAtAsc(UUID patientId);

    void deleteByPatientId(UUID patientId);
}
