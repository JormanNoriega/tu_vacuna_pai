package com.pai.api.patients.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Representacion completa de un paciente autorizado. */
public record PatientResponse(
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
    String status,
    long version,
    Instant createdAt,
    Instant updatedAt,
    DemographicDto demographics,
    List<ContactDto> contacts,
    List<AddressDto> addresses,
    List<GuardianDto> guardians,
    List<MedicalHistoryDto> medicalHistories,
    AffiliationDto affiliation,
    SpecialConditionsDto specialConditions,
    UserConditionDto userCondition) {

  public record DemographicDto(
      String gender, String ethnicity, String sexualOrientation, String educationLevel) {}

  public record ContactDto(UUID id, String type, String value, String phoneKind, boolean primary) {}

  public record AddressDto(
      UUID id,
      String street,
      UUID municipalityId,
      UUID departmentId,
      UUID countryId,
      String locality,
      String area,
      boolean primary) {}

  public record GuardianDto(
      UUID id,
      String relationship,
      String fullName,
      String secondName,
      String secondLastName,
      String documentType,
      String documentNumber,
      String phone,
      String landline,
      String cellphone,
      String email,
      String affiliationRegime,
      String insurer,
      String insurerCode,
      String ethnicity,
      Boolean displaced) {}

  public record MedicalHistoryDto(
      UUID id,
      String condition,
      LocalDate diagnosedAt,
      String notes,
      boolean hasContraindication,
      String contraindicationDetails,
      boolean hasPreviousReaction,
      String reactionDetails,
      String historyType,
      String specialObservations) {}

  public record AffiliationDto(String affiliationRegime, String insurer, String insurerCode) {}

  public record SpecialConditionsDto(
      boolean displaced,
      boolean disabled,
      boolean deceased,
      boolean armedConflictVictim,
      Boolean currentlyStudying) {}

  public record UserConditionDto(
      String userCondition,
      LocalDate lastMenstrualDate,
      Integer gestationWeeks,
      LocalDate probableDeliveryDate,
      Integer previousPregnancies,
      Boolean hasGivenBirth,
      String birthPlaceDelivery) {}
}
