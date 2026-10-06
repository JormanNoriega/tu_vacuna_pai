package com.pai.api.patients.repository;

import com.pai.api.patients.entity.PatientDemographicEntity;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientDemographicRepository
    extends JpaRepository<PatientDemographicEntity, UUID> {

  Optional<PatientDemographicEntity> findByPatientId(UUID patientId);

  /** Demografias de varios pacientes en una sola consulta (evita el N+1 del listado). */
  List<PatientDemographicEntity> findByPatientIdIn(Collection<UUID> patientIds);
}
