package com.pai.api.synchronization.service.command;

import com.pai.api.patients.dto.CreatePatientRequest;
import com.pai.api.patients.service.PatientService;
import com.pai.api.synchronization.dto.SyncOperation;
import java.util.UUID;
import org.springframework.stereotype.Component;

/** Aplica {@code CREATE_PATIENT} delegando en {@link PatientService}. */
@Component
public class CreatePatientCommandHandler implements SyncCommandHandler {

  public static final String COMMAND = "CREATE_PATIENT";

  private final PatientService patients;
  private final SyncPayloadConverter payload;

  public CreatePatientCommandHandler(PatientService patients, SyncPayloadConverter payload) {
    this.patients = patients;
    this.payload = payload;
  }

  @Override
  public String commandType() {
    return COMMAND;
  }

  @Override
  public String permission() {
    return "PATIENT_WRITE";
  }

  @Override
  public void apply(UUID actorId, String operationId, SyncOperation operation) {
    patients.create(
        actorId,
        operationId,
        operation.aggregateId(),
        payload.convert(operation, CreatePatientRequest.class));
  }
}
