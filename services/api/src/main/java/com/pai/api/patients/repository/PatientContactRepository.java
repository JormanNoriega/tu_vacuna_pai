package com.pai.api.patients.repository;

import com.pai.api.patients.entity.PatientContactEntity;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientContactRepository extends JpaRepository<PatientContactEntity, UUID> {

  List<PatientContactEntity> findByPatientIdOrderByCreatedAtAsc(UUID patientId);

  /** Contactos de varios pacientes en una sola consulta (evita el N+1 del listado). */
  List<PatientContactEntity> findByPatientIdInOrderByCreatedAtAsc(Collection<UUID> patientIds);

  void deleteByPatientId(UUID patientId);
}
