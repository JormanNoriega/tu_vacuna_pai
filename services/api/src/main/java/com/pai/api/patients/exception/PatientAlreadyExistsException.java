package com.pai.api.patients.exception;

import com.pai.api.shared.exceptions.DomainRuntimeException;
import java.util.UUID;
import org.springframework.http.HttpStatus;

/**
 * El paciente ya existe en la institucion para el tipo y numero de documento
 * indicados. La identidad de negocio es {@code (institution, documentType,
 * documentNumber)}; un duplicado no se fusiona automaticamente (invariante
 * {@code does_not_auto_merge_patient_identity}).
 *
 * <p>Transporta el id del paciente existente para que el motor de sincronizacion
 * pueda abrir un {@code PatientMergeRequest} (D11).
 */
public class PatientAlreadyExistsException extends DomainRuntimeException {

  private final UUID existingPatientId;

  public PatientAlreadyExistsException(String message) {
    this(message, null);
  }

  public PatientAlreadyExistsException(String message, UUID existingPatientId) {
    super(message);
    this.existingPatientId = existingPatientId;
  }

  public UUID getExistingPatientId() {
    return existingPatientId;
  }

  @Override
  public String errorCode() {
    return "PATIENT_ALREADY_EXISTS";
  }

  @Override
  public HttpStatus status() {
    return HttpStatus.CONFLICT;
  }
}
