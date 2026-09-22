package com.pai.api.patients.service;

import com.pai.api.attentions.service.PatientScopePolicy;
import com.pai.api.patients.repository.PatientRepository;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Implementacion de {@link PatientScopePolicy} sobre la persistencia de
 * pacientes. Vive en el modulo {@code patients} para que el modulo clinico no
 * dependa de su repositorio (DIP).
 */
@Service
public class PatientScopeService implements PatientScopePolicy {

  private final PatientRepository patients;

  public PatientScopeService(PatientRepository patients) {
    this.patients = patients;
  }

  @Override
  @Transactional(readOnly = true)
  public boolean existsInInstitution(UUID patientId, UUID institutionId) {
    return patients.findByIdAndInstitutionId(patientId, institutionId).isPresent();
  }
}
