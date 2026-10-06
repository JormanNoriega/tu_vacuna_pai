package com.pai.api.patients.support;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.patients.dto.CreatePatientRequest;
import com.pai.api.patients.entity.PatientEntity;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Fixtures compartidas por los tests del modulo de pacientes (DRY). */
public final class PatientTestFixtures {

  private PatientTestFixtures() {}

  /** Institucion activa con la ventana offline por defecto (72 h). */
  public static InstitutionEntity institution(UUID id) {
    Instant now = Instant.now();
    return new InstitutionEntity(
        id, "HOSP-A", "Hospital A", InstitutionEntity.Status.ACTIVE, (short) 72, now, now);
  }

  /** Actor {@code VACCINATOR} con lectura y escritura de pacientes. */
  public static AuthorizedUser vaccinator(UUID actorId, UUID institutionId) {
    return new AuthorizedUser(
        actorId,
        "vac@hosp.a",
        "Ana Vacunadora",
        institution(institutionId),
        List.of("VACCINATOR"),
        List.of("PATIENT_READ", "PATIENT_WRITE"),
        Instant.now());
  }

  /** Paciente minimo (identidad base) para respuestas y busquedas. */
  public static PatientEntity patient(UUID id, UUID institutionId) {
    return new PatientEntity(
        id,
        institutionId,
        "CC",
        "12345678",
        "Juan",
        "Perez",
        LocalDate.of(2020, 5, 1),
        PatientEntity.Sex.MALE,
        Instant.now());
  }

  /** Alta minima valida (adulto, sin bloques opcionales). */
  public static CreatePatientRequest request(String documentNumber, LocalDate birthDate) {
    return new CreatePatientRequest(
        "CC",
        documentNumber,
        "Juan",
        null,
        "Perez",
        null,
        birthDate,
        "MALE",
        null,
        null,
        null,
        null,
        null,
        false,
        false,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null);
  }

  /** Alta minima con fecha de nacimiento por defecto (adulto). */
  public static CreatePatientRequest request(String documentNumber) {
    return request(documentNumber, LocalDate.of(1990, 5, 1));
  }
}
