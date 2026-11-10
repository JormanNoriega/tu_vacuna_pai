package com.pai.api.patients.service;

import com.pai.api.catalog.entity.GeoDepartmentEntity;
import com.pai.api.catalog.entity.GeoMunicipalityEntity;
import com.pai.api.catalog.repository.GeoDepartmentRepository;
import com.pai.api.catalog.repository.GeoMunicipalityRepository;
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
import com.pai.api.patients.repository.PatientRepository;
import com.pai.api.patients.repository.PatientSpecialConditionRepository;
import com.pai.api.patients.repository.PatientUserConditionRepository;
import com.pai.api.reports.domain.PatientIdentity;
import com.pai.api.reports.service.PatientIdentityQuery;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Implementacion de {@link PatientIdentityQuery} en el modulo {@code patients}
 * (DIP): devuelve la identidad y perfil ampliado de los pacientes indicados,
 * consultando en bloque para evitar consultas N+1.
 */
@Service
public class PatientIdentityQueryService implements PatientIdentityQuery {

  private final PatientRepository patients;
  private final PatientDemographicRepository demographics;
  private final PatientAddressRepository addresses;
  private final PatientAffiliationRepository affiliations;
  private final PatientSpecialConditionRepository specialConditions;
  private final PatientUserConditionRepository userConditions;
  private final PatientMedicalHistoryRepository medicalHistories;
  private final PatientGuardianRepository guardians;
  private final PatientContactRepository contacts;
  private final GeoDepartmentRepository geoDepartments;
  private final GeoMunicipalityRepository geoMunicipalities;

  public PatientIdentityQueryService(
      PatientRepository patients,
      PatientDemographicRepository demographics,
      PatientAddressRepository addresses,
      PatientAffiliationRepository affiliations,
      PatientSpecialConditionRepository specialConditions,
      PatientUserConditionRepository userConditions,
      PatientMedicalHistoryRepository medicalHistories,
      PatientGuardianRepository guardians,
      PatientContactRepository contacts,
      GeoDepartmentRepository geoDepartments,
      GeoMunicipalityRepository geoMunicipalities) {
    this.patients = patients;
    this.demographics = demographics;
    this.addresses = addresses;
    this.affiliations = affiliations;
    this.specialConditions = specialConditions;
    this.userConditions = userConditions;
    this.medicalHistories = medicalHistories;
    this.guardians = guardians;
    this.contacts = contacts;
    this.geoDepartments = geoDepartments;
    this.geoMunicipalities = geoMunicipalities;
  }

  @Override
  @Transactional(readOnly = true)
  public List<PatientIdentity> byIds(Collection<UUID> patientIds) {
    if (patientIds == null || patientIds.isEmpty()) {
      return List.of();
    }

    List<PatientEntity> patientList = patients.findAllById(patientIds);

    Map<UUID, PatientDemographicEntity> demoMap =
        demographics.findAllById(patientIds).stream()
            .collect(Collectors.toMap(PatientDemographicEntity::getPatientId, d -> d));

    List<PatientAddressEntity> allAddresses =
        addresses.findByPatientIdInOrderByCreatedAtAsc(patientIds);
    Map<UUID, List<PatientAddressEntity>> addressMap =
        allAddresses.stream().collect(Collectors.groupingBy(PatientAddressEntity::getPatientId));

    Set<UUID> departmentIds =
        allAddresses.stream()
            .map(PatientAddressEntity::getDepartmentId)
            .filter(Objects::nonNull)
            .collect(Collectors.toSet());

    Set<UUID> municipalityIds =
        allAddresses.stream()
            .map(PatientAddressEntity::getMunicipalityId)
            .filter(Objects::nonNull)
            .collect(Collectors.toSet());

    Map<UUID, GeoMunicipalityEntity> municipalityMap =
        municipalityIds.isEmpty()
            ? Collections.emptyMap()
            : geoMunicipalities.findAllById(municipalityIds).stream()
                .collect(Collectors.toMap(GeoMunicipalityEntity::getId, m -> m));

    Set<UUID> allDepartmentIds = new HashSet<>(departmentIds);
    for (GeoMunicipalityEntity mun : municipalityMap.values()) {
      if (mun.getDepartmentId() != null) {
        allDepartmentIds.add(mun.getDepartmentId());
      }
    }

    Map<UUID, String> departmentNames =
        allDepartmentIds.isEmpty()
            ? Collections.emptyMap()
            : geoDepartments.findAllById(allDepartmentIds).stream()
                .collect(Collectors.toMap(GeoDepartmentEntity::getId, GeoDepartmentEntity::getName));

    Map<UUID, PatientAffiliationEntity> affilMap =
        affiliations.findAllById(patientIds).stream()
            .collect(Collectors.toMap(PatientAffiliationEntity::getPatientId, a -> a));

    Map<UUID, PatientSpecialConditionEntity> specMap =
        specialConditions.findAllById(patientIds).stream()
            .collect(Collectors.toMap(PatientSpecialConditionEntity::getPatientId, s -> s));

    Map<UUID, PatientUserConditionEntity> condMap =
        userConditions.findAllById(patientIds).stream()
            .collect(Collectors.toMap(PatientUserConditionEntity::getPatientId, c -> c));

    Map<UUID, List<PatientMedicalHistoryEntity>> medMap =
        medicalHistories.findByPatientIdInOrderByCreatedAtAsc(patientIds).stream()
            .collect(Collectors.groupingBy(PatientMedicalHistoryEntity::getPatientId));

    Map<UUID, List<PatientGuardianEntity>> guardMap =
        guardians.findByPatientIdInOrderByCreatedAtAsc(patientIds).stream()
            .collect(Collectors.groupingBy(PatientGuardianEntity::getPatientId));

    Map<UUID, List<PatientContactEntity>> contactMap =
        contacts.findByPatientIdInOrderByCreatedAtAsc(patientIds).stream()
            .collect(Collectors.groupingBy(PatientContactEntity::getPatientId));

    return patientList.stream()
        .map(
            patient ->
                toIdentity(
                    patient,
                    demoMap.get(patient.getId()),
                    primaryAddress(addressMap.get(patient.getId())),
                    departmentNames,
                    municipalityMap,
                    affilMap.get(patient.getId()),
                    specMap.get(patient.getId()),
                    condMap.get(patient.getId()),
                    primaryMedicalHistory(medMap.get(patient.getId())),
                    guardianByRelationship(guardMap.get(patient.getId()), "MOTHER"),
                    guardianByRelationship(guardMap.get(patient.getId()), "CAREGIVER"),
                    contactMap.get(patient.getId())))
        .toList();
  }

  private static PatientAddressEntity primaryAddress(List<PatientAddressEntity> list) {
    if (list == null || list.isEmpty()) return null;
    return list.stream()
        .filter(PatientAddressEntity::isPrimary)
        .findFirst()
        .orElseGet(() -> list.get(0));
  }

  private static PatientMedicalHistoryEntity primaryMedicalHistory(
      List<PatientMedicalHistoryEntity> list) {
    if (list == null || list.isEmpty()) return null;
    return list.get(0);
  }

  private static PatientGuardianEntity guardianByRelationship(
      List<PatientGuardianEntity> list, String relationship) {
    if (list == null || list.isEmpty()) return null;
    return list.stream()
        .filter(g -> relationship.equalsIgnoreCase(g.getRelationship()))
        .findFirst()
        .orElse(null);
  }

  private static PatientIdentity toIdentity(
      PatientEntity patient,
      PatientDemographicEntity demo,
      PatientAddressEntity address,
      Map<UUID, String> departmentNames,
      Map<UUID, GeoMunicipalityEntity> municipalityMap,
      PatientAffiliationEntity affil,
      PatientSpecialConditionEntity spec,
      PatientUserConditionEntity cond,
      PatientMedicalHistoryEntity med,
      PatientGuardianEntity mother,
      PatientGuardianEntity caregiver,
      List<PatientContactEntity> contactList) {

    String phone = null;
    String cellphone = null;
    String email = null;
    if (contactList != null) {
      for (PatientContactEntity c : contactList) {
        if ("EMAIL".equalsIgnoreCase(c.getType())) {
          email = c.getValue();
        } else if ("PHONE".equalsIgnoreCase(c.getType())) {
          if ("LANDLINE".equalsIgnoreCase(c.getPhoneKind())) {
            phone = c.getValue();
          } else {
            cellphone = c.getValue();
          }
        }
      }
    }

    UUID depId = address != null ? address.getDepartmentId() : null;
    UUID munId = address != null ? address.getMunicipalityId() : null;
    GeoMunicipalityEntity munEntity = munId != null ? municipalityMap.get(munId) : null;
    if (depId == null && munEntity != null) {
      depId = munEntity.getDepartmentId();
    }
    String depName = depId != null ? departmentNames.get(depId) : null;
    String munName = munEntity != null ? munEntity.getName() : null;

    return new PatientIdentity(
        patient.getId(),
        patient.getDocumentType(),
        patient.getDocumentNumber(),
        patient.getFirstName(),
        patient.getSecondName(),
        patient.getLastName(),
        patient.getSecondLastName(),
        patient.getBirthDate(),
        patient.getSex().name(),
        demo != null ? demo.getGender() : null,
        demo != null ? demo.getSexualOrientation() : null,
        patient.getGestationalAgeAtBirth(),
        "COLOMBIA",
        patient.getMigrationStatus(),
        patient.getBirthPlace() != null
            ? patient.getBirthPlace()
            : (cond != null ? cond.getBirthPlaceDelivery() : null),
        affil != null ? affil.getAffiliationRegime() : null,
        affil != null ? affil.getInsurer() : null,
        demo != null ? demo.getEthnicity() : null,
        spec != null && spec.isDisplaced(),
        spec != null && spec.isDisabled(),
        spec != null && spec.isDeceased(),
        spec != null && spec.isArmedConflictVictim(),
        spec != null && Boolean.TRUE.equals(spec.getCurrentlyStudying()),
        "COLOMBIA",
        depName,
        munName,
        address != null ? address.getLocality() : null,
        address != null ? address.getArea() : null,
        address != null ? address.getStreet() : null,
        phone,
        cellphone,
        email,
        patient.isAuthorizeCalls(),
        patient.isAuthorizeEmail(),
        med != null && med.isHasContraindication(),
        med != null ? med.getContraindicationDetails() : null,
        med != null && med.isHasPreviousReaction(),
        med != null ? med.getReactionDetails() : null,
        cond != null ? cond.getUserCondition() : null,
        cond != null ? cond.getLastMenstrualDate() : null,
        cond != null ? cond.getGestationWeeks() : null,
        cond != null ? cond.getProbableDeliveryDate() : null,
        cond != null ? cond.getPreviousPregnancies() : null,
        med != null ? med.getDiagnosedAt() : null,
        med != null ? med.getHistoryType() : null,
        med != null ? med.getNotes() : null,
        med != null ? med.getSpecialObservations() : null,
        mother != null ? mother.getDocumentType() : null,
        mother != null ? mother.getDocumentNumber() : null,
        mother != null ? mother.getFullName() : null,
        mother != null ? mother.getSecondName() : null,
        mother != null ? mother.getSecondLastName() : null,
        mother != null ? mother.getSecondLastName() : null,
        mother != null ? mother.getEmail() : null,
        mother != null ? mother.getLandline() : null,
        mother != null
            ? (mother.getCellphone() != null ? mother.getCellphone() : mother.getPhone())
            : null,
        mother != null ? mother.getAffiliationRegime() : null,
        mother != null ? mother.getEthnicity() : null,
        mother != null && Boolean.TRUE.equals(mother.getDisplaced()),
        caregiver != null ? caregiver.getDocumentType() : null,
        caregiver != null ? caregiver.getDocumentNumber() : null,
        caregiver != null ? caregiver.getFullName() : null,
        caregiver != null ? caregiver.getSecondName() : null,
        caregiver != null ? caregiver.getSecondLastName() : null,
        caregiver != null ? caregiver.getSecondLastName() : null,
        caregiver != null ? caregiver.getRelationship() : null,
        caregiver != null ? caregiver.getEmail() : null,
        caregiver != null ? caregiver.getLandline() : null,
        caregiver != null
            ? (caregiver.getCellphone() != null
                ? caregiver.getCellphone()
                : caregiver.getPhone())
            : null,
        patient.getVaccinationCardType(),
        demo != null ? demo.getEducationLevel() : null,
        affil != null ? affil.getInsurerCode() : null,
        cond != null ? cond.getHasGivenBirth() : null,
        cond != null ? cond.getBirthPlaceDelivery() : null,
        mother != null ? mother.getInsurer() : null,
        caregiver != null ? caregiver.getAffiliationRegime() : null,
        caregiver != null ? caregiver.getInsurer() : null,
        caregiver != null ? caregiver.getEthnicity() : null,
        caregiver != null ? caregiver.getDisplaced() : null);
  }
}
