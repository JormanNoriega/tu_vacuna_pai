package com.pai.api.patients.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Alta de un paciente. El documento y el nombre son obligatorios; el resto del
 * perfil (identidad ampliada, demografia, contactos, direcciones, tutores,
 * antecedentes, afiliacion y condiciones) es opcional. El documento viaja crudo:
 * el backend lo normaliza y valida antes de persistir.
 */
public record CreatePatientRequest(
    @NotBlank(message = "El tipo de documento es obligatorio.")
    String documentType,

    @NotBlank(message = "El numero de documento es obligatorio.")
    String documentNumber,

    @NotBlank(message = "El nombre es obligatorio.")
    @Size(max = 120, message = "El nombre no puede superar 120 caracteres.")
    String firstName,

    @Size(max = 120, message = "El segundo nombre no puede superar 120 caracteres.")
    String secondName,

    @NotBlank(message = "El apellido es obligatorio.")
    @Size(max = 120, message = "El apellido no puede superar 120 caracteres.")
    String lastName,

    @Size(max = 120, message = "El segundo apellido no puede superar 120 caracteres.")
    String secondLastName,

    @NotNull(message = "La fecha de nacimiento es obligatoria.")
    LocalDate birthDate,

    @NotBlank(message = "El sexo es obligatorio.") String sex,

    UUID birthCountryId,

    @Size(max = 200, message = "El lugar de nacimiento no puede superar 200 caracteres.")
    String birthPlace,

    @Size(max = 20, message = "El estatus migratorio no puede superar 20 caracteres.")
    String migrationStatus,

    Integer gestationalAgeAtBirth,

    @Size(max = 40, message = "El tipo de carnet no puede superar 40 caracteres.")
    String vaccinationCardType,

    Boolean authorizeCalls,

    Boolean authorizeEmail,

    @Valid DemographicDto demographics,

    @Valid List<ContactDto> contacts,

    @Valid List<AddressDto> addresses,

    @Valid List<GuardianDto> guardians,

    @Valid List<MedicalHistoryDto> medicalHistories,

    @Valid AffiliationDto affiliation,

    @Valid SpecialConditionsDto specialConditions,

    @Valid UserConditionDto userCondition) {

  public record DemographicDto(
      @Size(max = 20, message = "El genero no puede superar 20 caracteres.")
      String gender,

      @Size(max = 80, message = "La etnia no puede superar 80 caracteres.")
      String ethnicity,

      @Size(max = 40, message = "La orientacion sexual no puede superar 40 caracteres.")
      String sexualOrientation,

      @Size(max = 120, message = "La escolaridad no puede superar 120 caracteres.")
      String educationLevel) {}

  public record ContactDto(
      @NotBlank(message = "El tipo de contacto es obligatorio.")
      String type,

      @NotBlank(message = "El valor del contacto es obligatorio.")
      @Size(max = 120, message = "El contacto no puede superar 120 caracteres.")
      String value,

      @Size(max = 20, message = "El tipo de telefono no puede superar 20 caracteres.")
      String phoneKind,

      Boolean primary) {}

  public record AddressDto(
      @Size(max = 200, message = "La direccion no puede superar 200 caracteres.")
      String street,

      UUID municipalityId,
      UUID departmentId,
      UUID countryId,

      @Size(max = 120, message = "La comuna no puede superar 120 caracteres.")
      String locality,

      @Size(max = 20, message = "El area no puede superar 20 caracteres.")
      String area,

      Boolean primary) {}

  public record GuardianDto(
      @NotBlank(message = "El parentesco es obligatorio.") String relationship,

      @NotBlank(message = "El nombre del tutor es obligatorio.")
      @Size(max = 120, message = "El nombre del tutor no puede superar 120 caracteres.")
      String fullName,

      @Size(max = 120, message = "El segundo nombre no puede superar 120 caracteres.")
      String secondName,

      @Size(max = 120, message = "El segundo apellido no puede superar 120 caracteres.")
      String secondLastName,

      @Size(max = 20, message = "El tipo de documento no puede superar 20 caracteres.")
      String documentType,

      @Size(max = 20, message = "El documento no puede superar 20 caracteres.")
      String documentNumber,

      @Size(max = 20, message = "El telefono no puede superar 20 caracteres.")
      String phone,

      @Size(max = 20, message = "El telefono fijo no puede superar 20 caracteres.")
      String landline,

      @Size(max = 20, message = "El celular no puede superar 20 caracteres.")
      String cellphone,

      @Size(max = 120, message = "El correo no puede superar 120 caracteres.")
      String email,

      @Size(max = 40, message = "El regimen no puede superar 40 caracteres.")
      String affiliationRegime,

      @Size(max = 120, message = "La aseguradora no puede superar 120 caracteres.")
      String insurer,

      @Size(max = 40, message = "El codigo de aseguradora no puede superar 40 caracteres.")
      String insurerCode,

      @Size(max = 40, message = "La etnia no puede superar 40 caracteres.")
      String ethnicity,

      Boolean displaced) {}

  public record MedicalHistoryDto(
      @NotBlank(message = "El antecedente es obligatorio.")
      @Size(max = 200, message = "El antecedente no puede superar 200 caracteres.")
      String condition,

      LocalDate diagnosedAt,

      @Size(max = 500, message = "Las notas no pueden superar 500 caracteres.")
      String notes,

      Boolean hasContraindication,

      @Size(max = 120, message = "La contraindicacion no puede superar 120 caracteres.")
      String contraindicationDetails,

      Boolean hasPreviousReaction,

      @Size(max = 120, message = "La reaccion no puede superar 120 caracteres.")
      String reactionDetails,

      @Size(max = 60, message = "El tipo de antecedente no puede superar 60 caracteres.")
      String historyType,

      @Size(max = 500, message = "Las observaciones no pueden superar 500 caracteres.")
      String specialObservations) {}

  public record AffiliationDto(
      @Size(max = 40, message = "El regimen no puede superar 40 caracteres.")
      String affiliationRegime,

      @Size(max = 120, message = "La aseguradora no puede superar 120 caracteres.")
      String insurer,

      @Size(max = 40, message = "El codigo de aseguradora no puede superar 40 caracteres.")
      String insurerCode) {}

  public record SpecialConditionsDto(
      Boolean displaced,
      Boolean disabled,
      Boolean deceased,
      Boolean armedConflictVictim,
      Boolean currentlyStudying) {}

  public record UserConditionDto(
      @Size(max = 40, message = "La condicion no puede superar 40 caracteres.")
      String userCondition,

      LocalDate lastMenstrualDate,

      Integer gestationWeeks,

      LocalDate probableDeliveryDate,

      Integer previousPregnancies,

      Boolean hasGivenBirth,

      @Size(max = 200, message = "El lugar del parto no puede superar 200 caracteres.")
      String birthPlaceDelivery) {}
}
