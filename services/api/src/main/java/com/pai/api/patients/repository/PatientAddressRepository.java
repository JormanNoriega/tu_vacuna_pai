package com.pai.api.patients.repository;

import com.pai.api.patients.entity.PatientAddressEntity;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientAddressRepository extends JpaRepository<PatientAddressEntity, UUID> {

  List<PatientAddressEntity> findByPatientIdOrderByCreatedAtAsc(UUID patientId);

  /** Direcciones de varios pacientes en una sola consulta (evita el N+1 del listado). */
  List<PatientAddressEntity> findByPatientIdInOrderByCreatedAtAsc(Collection<UUID> patientIds);

  void deleteByPatientId(UUID patientId);
}
