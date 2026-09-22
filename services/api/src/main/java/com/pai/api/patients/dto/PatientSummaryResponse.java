package com.pai.api.patients.dto;

import java.time.LocalDate;
import java.util.UUID;

/**
 * Vista ligera de un paciente para listados (busqueda). Incluye la identidad y
 * los campos que el cliente necesita para mostrar la fila; omite las
 * sub-entidades y metadatos (ISP): el detalle completo se obtiene por
 * {@code GET /patients/{id}}.
 */
public record PatientSummaryResponse(
    UUID id,
    UUID institutionId,
    String documentType,
    String documentNumber,
    String firstName,
    String secondName,
    String lastName,
    String secondLastName,
    LocalDate birthDate,
    String sex,
    UUID birthCountryId,
    String birthPlace,
    String migrationStatus,
    Integer gestationalAgeAtBirth,
    String vaccinationCardType,
    boolean authorizeCalls,
    boolean authorizeEmail,
    String status) {}
