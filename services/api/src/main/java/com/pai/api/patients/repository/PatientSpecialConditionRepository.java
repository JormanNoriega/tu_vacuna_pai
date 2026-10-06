package com.pai.api.patients.repository;

import com.pai.api.patients.entity.PatientSpecialConditionEntity;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PatientSpecialConditionRepository
    extends JpaRepository<PatientSpecialConditionEntity, UUID> {

  Optional<PatientSpecialConditionEntity> findByPatientId(UUID patientId);

  /** Condiciones de varios pacientes en una sola consulta (evita el N+1 del listado). */
  List<PatientSpecialConditionEntity> findByPatientIdIn(Collection<UUID> patientIds);
}
