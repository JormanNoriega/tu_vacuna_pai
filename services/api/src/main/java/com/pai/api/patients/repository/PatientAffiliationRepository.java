package com.pai.api.patients.repository;

import com.pai.api.patients.entity.PatientAffiliationEntity;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientAffiliationRepository
    extends JpaRepository<PatientAffiliationEntity, UUID> {

  Optional<PatientAffiliationEntity> findByPatientId(UUID patientId);

  /** Afiliaciones de varios pacientes en una sola consulta (evita el N+1 del listado). */
  List<PatientAffiliationEntity> findByPatientIdIn(Collection<UUID> patientIds);
}
