package com.pai.api.patients.service;

import com.pai.api.patients.dto.CreatePatientRequest;
import com.pai.api.patients.dto.PatientResponse;
import com.pai.api.patients.dto.UpdatePatientContactRequest;
import com.pai.api.patients.dto.UpdatePatientDemographicsRequest;
import com.pai.api.patients.dto.UpdatePatientMedicalHistoriesRequest;
import com.pai.api.patients.entity.PatientAddressEntity;
import com.pai.api.patients.entity.PatientAffiliationEntity;
import com.pai.api.patients.entity.PatientContactEntity;
import com.pai.api.patients.entity.PatientDemographicEntity;
import com.pai.api.patients.entity.PatientEntity;
import com.pai.api.patients.entity.PatientGuardianEntity;
import com.pai.api.patients.entity.PatientMedicalHistoryEntity;
import com.pai.api.patients.entity.PatientSpecialConditionEntity;
import com.pai.api.patients.entity.PatientUserConditionEntity;
import com.pai.api.patients.repository.PatientAddressRepository;
import com.pai.api.patients.repository.PatientAffiliationRepository;
import com.pai.api.patients.repository.PatientContactRepository;
import com.pai.api.patients.repository.PatientDemographicRepository;
import com.pai.api.patients.repository.PatientGuardianRepository;
import com.pai.api.patients.repository.PatientMedicalHistoryRepository;
import com.pai.api.patients.repository.PatientSpecialConditionRepository;
import com.pai.api.patients.repository.PatientUserConditionRepository;
import com.pai.api.shared.util.DocumentNormalizer;
import com.pai.api.shared.util.Strings;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;

/**
 * Persistencia y ensamblado de las sub-entidades del paciente (SRP): encapsula
 * el acceso a los repositorios hijos (demografia, contactos, direcciones,
 * tutores, antecedentes, afiliacion, condiciones) para que
 * {@link PatientService} solo orqueste el agregado.
 */
@Component
public class PatientSubEntitiesWriter {

  private final PatientContactRepository contacts;
  private final PatientDemographicRepository demographics;
  private final PatientAddressRepository addresses;
  private final PatientGuardianRepository guardians;
  private final PatientMedicalHistoryRepository medicalHistories;
  private final PatientAffiliationRepository affiliations;
  private final PatientSpecialConditionRepository specialConditions;
  private final PatientUserConditionRepository userConditions;
  private final PatientMapper mapper;

  public PatientSubEntitiesWriter(
      PatientContactRepository contacts,
      PatientDemographicRepository demographics,
      PatientAddressRepository addresses,
      PatientGuardianRepository guardians,
      PatientMedicalHistoryRepository medicalHistories,
      PatientAffiliationRepository affiliations,
      PatientSpecialConditionRepository specialConditions,
      PatientUserConditionRepository userConditions,
      PatientMapper mapper) {
    this.contacts = contacts;
    this.demographics = demographics;
    this.addresses = addresses;
    this.guardians = guardians;
    this.medicalHistories = medicalHistories;
    this.affiliations = affiliations;
    this.specialConditions = specialConditions;
    this.userConditions = userConditions;
    this.mapper = mapper;
  }

  /** Persiste las 8 sub-entidades de un alta. */
  public void saveAll(UUID patientId, CreatePatientRequest request, Instant now) {
    saveDemographics(patientId, request.demographics(), now);
    saveContacts(patientId, request.contacts(), now);
    saveAddresses(patientId, request.addresses(), now);
    saveGuardians(patientId, request.guardians(), now);
    saveMedicalHistories(patientId, request.medicalHistories(), now);
    saveAffiliation(patientId, request.affiliation(), now);
    saveSpecialConditions(patientId, request.specialConditions(), now);
    saveUserCondition(patientId, request.userCondition(), now);
  }

  /** Reemplaza contactos y direcciones del paciente. */
  public void replaceContact(UUID patientId, UpdatePatientContactRequest request, Instant now) {
    contacts.deleteByPatientId(patientId);
    addresses.deleteByPatientId(patientId);
    for (UpdatePatientContactRequest.ContactDto dto : Strings.safe(request.contacts())) {
      saveContact(patientId, dto.type(), dto.value(), null, dto.primary(), now);
    }
    for (UpdatePatientContactRequest.AddressDto dto : Strings.safe(request.addresses())) {
      saveAddress(
          patientId,
          dto.street(),
          dto.municipalityId(),
          dto.departmentId(),
          dto.countryId(),
          null,
          null,
          dto.primary(),
          now);
    }
  }

  /** Reemplaza la demografia del paciente (valida el genero antes de borrar). */
  public void replaceDemographics(
      UUID patientId, UpdatePatientDemographicsRequest request, Instant now) {
    String gender = PatientFieldParser.normalizeGender(request.gender());
    demographics.findByPatientId(patientId).ifPresent(demographics::delete);
    demographics.save(new PatientDemographicEntity(
        patientId,
        gender,
        Strings.blankToNull(request.ethnicity()),
        Strings.blankToNull(request.educationLevel()),
        now));
  }

  /** Reemplaza los antecedentes del paciente. */
  public void replaceMedicalHistories(
      UUID patientId, UpdatePatientMedicalHistoriesRequest request, Instant now) {
    medicalHistories.deleteByPatientId(patientId);
    for (UpdatePatientMedicalHistoriesRequest.MedicalHistoryDto dto :
        Strings.safe(request.medicalHistories())) {
      medicalHistories.save(new PatientMedicalHistoryEntity(
          UUID.randomUUID(),
          patientId,
          dto.condition().trim(),
          dto.diagnosedAt(),
          Strings.blankToNull(dto.notes()),
          now));
    }
  }

  /** Carga las sub-entidades y ensambla la respuesta completa de un paciente. */
  public PatientResponse assemble(PatientEntity patient) {
    return assembleMany(List.of(patient)).get(0);
  }

  /**
   * Ensambla la respuesta de varios pacientes cargando sus sub-entidades en
   * bloque (1 consulta por tabla, sin N+1).
   */
  public List<PatientResponse> assembleMany(List<PatientEntity> patientList) {
    if (patientList.isEmpty()) {
      return List.of();
    }
    List<UUID> patientIds = patientList.stream().map(PatientEntity::getId).toList();

    Map<UUID, PatientDemographicEntity> demographicByPatient = indexUnique(
        demographics.findByPatientIdIn(patientIds), PatientDemographicEntity::getPatientId);
    Map<UUID, PatientAffiliationEntity> affiliationByPatient = indexUnique(
        affiliations.findByPatientIdIn(patientIds), PatientAffiliationEntity::getPatientId);
    Map<UUID, PatientSpecialConditionEntity> specialByPatient = indexUnique(
        specialConditions.findByPatientIdIn(patientIds),
        PatientSpecialConditionEntity::getPatientId);
    Map<UUID, PatientUserConditionEntity> userConditionByPatient = indexUnique(
        userConditions.findByPatientIdIn(patientIds), PatientUserConditionEntity::getPatientId);

    Map<UUID, List<PatientContactEntity>> contactsByPatient = group(
        contacts.findByPatientIdInOrderByCreatedAtAsc(patientIds),
        PatientContactEntity::getPatientId);
    Map<UUID, List<PatientAddressEntity>> addressesByPatient = group(
        addresses.findByPatientIdInOrderByCreatedAtAsc(patientIds),
        PatientAddressEntity::getPatientId);
    Map<UUID, List<PatientGuardianEntity>> guardiansByPatient = group(
        guardians.findByPatientIdInOrderByCreatedAtAsc(patientIds),
        PatientGuardianEntity::getPatientId);
    Map<UUID, List<PatientMedicalHistoryEntity>> historiesByPatient = group(
        medicalHistories.findByPatientIdInOrderByCreatedAtAsc(patientIds),
        PatientMedicalHistoryEntity::getPatientId);

    return patientList.stream()
        .map(patient -> mapper.toResponse(
            patient,
            demographicByPatient.get(patient.getId()),
            contactsByPatient.getOrDefault(patient.getId(), List.of()),
            addressesByPatient.getOrDefault(patient.getId(), List.of()),
            guardiansByPatient.getOrDefault(patient.getId(), List.of()),
            historiesByPatient.getOrDefault(patient.getId(), List.of()),
            affiliationByPatient.get(patient.getId()),
            specialByPatient.get(patient.getId()),
            userConditionByPatient.get(patient.getId())))
        .toList();
  }

  private void saveDemographics(
      UUID patientId, CreatePatientRequest.DemographicDto dto, Instant now) {
    if (dto == null) {
      return;
    }
    demographics.save(new PatientDemographicEntity(
        patientId,
        Strings.blankToNull(dto.gender()),
        Strings.blankToNull(dto.ethnicity()),
        PatientFieldParser.normalizeUpper(dto.sexualOrientation()),
        Strings.blankToNull(dto.educationLevel()),
        now));
  }

  private void saveAffiliation(
      UUID patientId, CreatePatientRequest.AffiliationDto dto, Instant now) {
    if (dto == null) {
      return;
    }
    if (Strings.blankToNull(dto.affiliationRegime()) == null
        && Strings.blankToNull(dto.insurer()) == null) {
      return;
    }
    affiliations.save(new PatientAffiliationEntity(
        patientId,
        PatientFieldParser.normalizeUpper(dto.affiliationRegime()),
        Strings.blankToNull(dto.insurer()),
        Strings.blankToNull(dto.insurerCode()),
        now));
  }

  private void saveSpecialConditions(
      UUID patientId, CreatePatientRequest.SpecialConditionsDto dto, Instant now) {
    if (dto == null) {
      return;
    }
    specialConditions.save(new PatientSpecialConditionEntity(
        patientId,
        Boolean.TRUE.equals(dto.displaced()),
        Boolean.TRUE.equals(dto.disabled()),
        Boolean.TRUE.equals(dto.deceased()),
        Boolean.TRUE.equals(dto.armedConflictVictim()),
        dto.currentlyStudying(),
        now));
  }

  private void saveUserCondition(
      UUID patientId, CreatePatientRequest.UserConditionDto dto, Instant now) {
    if (dto == null) {
      return;
    }
    userConditions.save(new PatientUserConditionEntity(
        patientId,
        PatientFieldParser.normalizeUpper(dto.userCondition()),
        dto.lastMenstrualDate(),
        dto.gestationWeeks(),
        dto.probableDeliveryDate(),
        dto.previousPregnancies(),
        dto.hasGivenBirth(),
        Strings.blankToNull(dto.birthPlaceDelivery()),
        now));
  }

  private void saveContacts(
      UUID patientId, List<CreatePatientRequest.ContactDto> list, Instant now) {
    for (CreatePatientRequest.ContactDto dto : Strings.safe(list)) {
      saveContact(
          patientId,
          dto.type(),
          dto.value(),
          dto.phoneKind(),
          Boolean.TRUE.equals(dto.primary()),
          now);
    }
  }

  private void saveAddresses(
      UUID patientId, List<CreatePatientRequest.AddressDto> list, Instant now) {
    for (CreatePatientRequest.AddressDto dto : Strings.safe(list)) {
      saveAddress(
          patientId,
          dto.street(),
          dto.municipalityId(),
          dto.departmentId(),
          dto.countryId(),
          dto.locality(),
          dto.area(),
          Boolean.TRUE.equals(dto.primary()),
          now);
    }
  }

  private void saveGuardians(
      UUID patientId, List<CreatePatientRequest.GuardianDto> list, Instant now) {
    for (CreatePatientRequest.GuardianDto dto : Strings.safe(list)) {
      guardians.save(new PatientGuardianEntity(
          UUID.randomUUID(),
          patientId,
          PatientFieldParser.relationship(dto.relationship()),
          dto.fullName().trim(),
          Strings.blankToNull(dto.secondName()),
          Strings.blankToNull(dto.secondLastName()),
          Strings.blankToNull(dto.documentType()),
          DocumentNormalizer.normalize(dto.documentNumber()),
          Strings.blankToNull(dto.phone()),
          Strings.blankToNull(dto.landline()),
          Strings.blankToNull(dto.cellphone()),
          Strings.blankToNull(dto.email()),
          PatientFieldParser.normalizeUpper(dto.affiliationRegime()),
          Strings.blankToNull(dto.insurer()),
          Strings.blankToNull(dto.insurerCode()),
          PatientFieldParser.normalizeUpper(dto.ethnicity()),
          dto.displaced(),
          now));
    }
  }

  private void saveMedicalHistories(
      UUID patientId, List<CreatePatientRequest.MedicalHistoryDto> list, Instant now) {
    for (CreatePatientRequest.MedicalHistoryDto dto : Strings.safe(list)) {
      medicalHistories.save(new PatientMedicalHistoryEntity(
          UUID.randomUUID(),
          patientId,
          dto.condition().trim(),
          dto.diagnosedAt(),
          Strings.blankToNull(dto.notes()),
          Boolean.TRUE.equals(dto.hasContraindication()),
          Strings.blankToNull(dto.contraindicationDetails()),
          Boolean.TRUE.equals(dto.hasPreviousReaction()),
          Strings.blankToNull(dto.reactionDetails()),
          Strings.blankToNull(dto.historyType()),
          Strings.blankToNull(dto.specialObservations()),
          now));
    }
  }

  private void saveContact(
      UUID patientId, String type, String value, String phoneKind, boolean primary, Instant now) {
    PatientRules.validatePhone(type, value);
    contacts.save(new PatientContactEntity(
        UUID.randomUUID(),
        patientId,
        PatientFieldParser.contactType(type),
        value.trim(),
        primary,
        PatientFieldParser.normalizeUpper(phoneKind),
        now));
  }

  private void saveAddress(
      UUID patientId,
      String street,
      UUID municipalityId,
      UUID departmentId,
      UUID countryId,
      String locality,
      String area,
      boolean primary,
      Instant now) {
    addresses.save(new PatientAddressEntity(
        UUID.randomUUID(),
        patientId,
        Strings.blankToNull(street),
        municipalityId,
        departmentId,
        countryId,
        Strings.blankToNull(locality),
        PatientFieldParser.normalizeUpper(area),
        primary,
        now));
  }

  private static <T> Map<UUID, List<T>> group(List<T> rows, Function<T, UUID> key) {
    return rows.stream().collect(Collectors.groupingBy(key));
  }

  private static <T> Map<UUID, T> indexUnique(List<T> rows, Function<T, UUID> key) {
    return rows.stream().collect(Collectors.toMap(key, row -> row));
  }
}
