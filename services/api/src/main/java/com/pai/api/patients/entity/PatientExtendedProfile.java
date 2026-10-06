package com.pai.api.patients.entity;

import java.util.UUID;

/**
 * Perfil ampliado del paciente capturado por el wizard (Paso 1/2). Command
 * object que reemplaza la lista posicional de 9 parametros de
 * {@link PatientEntity#applyExtendedProfile}.
 */
public record PatientExtendedProfile(
    String secondName,
    String secondLastName,
    UUID birthCountryId,
    String birthPlace,
    String migrationStatus,
    Integer gestationalAgeAtBirth,
    String vaccinationCardType,
    boolean authorizeCalls,
    boolean authorizeEmail) {}
