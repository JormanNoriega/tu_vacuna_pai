package com.pai.api.patients.repository;

import com.pai.api.patients.entity.PatientGuardianEntity;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientGuardianRepository extends JpaRepository<PatientGuardianEntity, UUID> {

  List<PatientGuardianEntity> findByPatientIdOrderByCreatedAtAsc(UUID patientId);

  /** Tutores de varios pacientes en una sola consulta (evita el N+1 del listado). */
  List<PatientGuardianEntity> findByPatientIdInOrderByCreatedAtAsc(Collection<UUID> patientIds);
}
