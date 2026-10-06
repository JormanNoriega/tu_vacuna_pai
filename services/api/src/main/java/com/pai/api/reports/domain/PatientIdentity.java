package com.pai.api.reports.domain;

import java.time.LocalDate;
import java.util.UUID;

/**
 * Identidad minima de un paciente para el reporte. La produce el modulo
 * {@code patients} a traves del puerto {@code PatientIdentityQuery}.
 */
public record PatientIdentity(
    UUID id,
    String documentType,
    String documentNumber,
    String firstName,
    String secondName,
    String lastName,
    String secondLastName,
    LocalDate birthDate,
    String sex) {}
