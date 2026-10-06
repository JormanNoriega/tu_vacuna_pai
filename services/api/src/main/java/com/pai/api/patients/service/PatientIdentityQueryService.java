package com.pai.api.patients.service;

import com.pai.api.patients.entity.PatientEntity;
import com.pai.api.patients.repository.PatientRepository;
import com.pai.api.reports.domain.PatientIdentity;
import com.pai.api.reports.service.PatientIdentityQuery;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Implementacion de {@link PatientIdentityQuery} en el modulo {@code patients}
 * (DIP): devuelve la identidad minima de los pacientes indicados, de modo que
 * {@code reports} no depende de la persistencia de pacientes.
 */
@Service
public class PatientIdentityQueryService implements PatientIdentityQuery {

  private final PatientRepository patients;

  public PatientIdentityQueryService(PatientRepository patients) {
    this.patients = patients;
  }

  @Override
  @Transactional(readOnly = true)
  public List<PatientIdentity> byIds(Collection<UUID> patientIds) {
    if (patientIds == null || patientIds.isEmpty()) {
      return List.of();
    }
    return patients.findAllById(patientIds).stream()
        .map(PatientIdentityQueryService::toIdentity)
        .toList();
  }

  private static PatientIdentity toIdentity(PatientEntity patient) {
    return new PatientIdentity(
        patient.getId(),
        patient.getDocumentType(),
        patient.getDocumentNumber(),
        patient.getFirstName(),
        patient.getSecondName(),
        patient.getLastName(),
        patient.getSecondLastName(),
        patient.getBirthDate(),
        patient.getSex().name());
  }
}
