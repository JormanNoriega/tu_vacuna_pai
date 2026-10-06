package com.pai.api.patients.repository;

import com.pai.api.patients.entity.PatientMedicalHistoryEntity;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientMedicalHistoryRepository
    extends JpaRepository<PatientMedicalHistoryEntity, UUID> {

  List<PatientMedicalHistoryEntity> findByPatientIdOrderByCreatedAtAsc(UUID patientId);

  /** Antecedentes de varios pacientes en una sola consulta (evita el N+1 del listado). */
  List<PatientMedicalHistoryEntity> findByPatientIdInOrderByCreatedAtAsc(
      Collection<UUID> patientIds);

  void deleteByPatientId(UUID patientId);
}
