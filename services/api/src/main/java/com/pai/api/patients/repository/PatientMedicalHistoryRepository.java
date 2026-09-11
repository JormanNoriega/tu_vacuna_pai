package com.pai.api.patients.repository;

import com.pai.api.patients.entity.PatientMedicalHistoryEntity;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientMedicalHistoryRepository extends JpaRepository<PatientMedicalHistoryEntity, UUID> {

    List<PatientMedicalHistoryEntity> findByPatientIdOrderByCreatedAtAsc(UUID patientId);

    void deleteByPatientId(UUID patientId);
}
