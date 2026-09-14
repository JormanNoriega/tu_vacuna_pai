package com.pai.api.patients.repository;

import com.pai.api.patients.entity.PatientContactEntity;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientContactRepository extends JpaRepository<PatientContactEntity, UUID> {

  List<PatientContactEntity> findByPatientIdOrderByCreatedAtAsc(UUID patientId);

  void deleteByPatientId(UUID patientId);
}
