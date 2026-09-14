package com.pai.api.patients.service;

import com.pai.api.patients.entity.PatientMergeRequestEntity;
import com.pai.api.patients.repository.PatientMergeRequestRepository;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Bandeja de identidades duplicadas (D6/D11). El motor de sincronizacion lo
 * invoca cuando un {@code CREATE_PATIENT} offline choca con el indice unico de
 * documento, para dejar la solicitud pendiente de resolucion online.
 */
@Service
public class PatientMergeRequestService {

  private final PatientMergeRequestRepository repository;

  public PatientMergeRequestService(PatientMergeRequestRepository repository) {
    this.repository = repository;
  }

  /**
   * Abre una solicitud {@code PENDING_REVIEW} para el paciente existente.
   * Es idempotente: si ya hay una pendiente para el mismo paciente no crea otra
   * (un reintento de push no debe multiplicar la bandeja). Devuelve {@code null}
   * si no hay paciente existente que referenciar.
   */
  @Transactional
  public PatientMergeRequestEntity requestReview(UUID existingPatientId) {
    if (existingPatientId == null) {
      return null;
    }
    if (repository.existsByDuplicatePatientIdAndStatus(
        existingPatientId, PatientMergeRequestEntity.Status.PENDING_REVIEW)) {
      return null;
    }
    return repository.save(new PatientMergeRequestEntity(
        UUID.randomUUID(),
        existingPatientId,
        PatientMergeRequestEntity.Status.PENDING_REVIEW,
        Instant.now()));
  }
}
