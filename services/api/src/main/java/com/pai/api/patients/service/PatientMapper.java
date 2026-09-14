package com.pai.api.patients.service;

import com.pai.api.patients.dto.PatientResponse;
import com.pai.api.patients.entity.PatientAddressEntity;
import com.pai.api.patients.entity.PatientAffiliationEntity;
import com.pai.api.patients.entity.PatientContactEntity;
import com.pai.api.patients.entity.PatientDemographicEntity;
import com.pai.api.patients.entity.PatientEntity;
import com.pai.api.patients.entity.PatientGuardianEntity;
import com.pai.api.patients.entity.PatientMedicalHistoryEntity;
import com.pai.api.patients.entity.PatientSpecialConditionEntity;
import com.pai.api.patients.entity.PatientUserConditionEntity;
import java.util.List;
import org.springframework.stereotype.Component;

/**
 * Convierte el agregado {@code Patient} (raiz + subentidades) en su DTO de
 * salida.
 *
 * <p>Extraido del servicio para respetar el principio de responsabilidad
 * unica (SRP): el mapeo entidad {@literal ->} DTO es una responsabilidad
 * distinta de la orquestacion y de la persistencia.
 */
@Component
public class PatientMapper {

  public PatientResponse toResponse(
      PatientEntity patient,
      PatientDemographicEntity demographic,
      List<PatientContactEntity> contacts,
      List<PatientAddressEntity> addresses,
      List<PatientGuardianEntity> guardians,
      List<PatientMedicalHistoryEntity> medicalHistories,
      PatientAffiliationEntity affiliation,
      PatientSpecialConditionEntity specialConditions,
      PatientUserConditionEntity userCondition) {

    PatientResponse.DemographicDto demographicDto = demographic == null
        ? null
        : new PatientResponse.DemographicDto(
            demographic.getGender(),
            demographic.getEthnicity(),
            demographic.getSexualOrientation(),
            demographic.getEducationLevel());

    List<PatientResponse.ContactDto> contactDtos = contacts.stream()
        .map(contact -> new PatientResponse.ContactDto(
            contact.getId(),
            contact.getType(),
            contact.getValue(),
            contact.getPhoneKind(),
            contact.isPrimary()))
        .toList();

    List<PatientResponse.AddressDto> addressDtos = addresses.stream()
        .map(address -> new PatientResponse.AddressDto(
            address.getId(),
            address.getStreet(),
            address.getMunicipalityId(),
            address.getDepartmentId(),
            address.getCountryId(),
            address.getLocality(),
            address.getArea(),
            address.isPrimary()))
        .toList();

    List<PatientResponse.GuardianDto> guardianDtos = guardians.stream()
        .map(guardian -> new PatientResponse.GuardianDto(
            guardian.getId(),
            guardian.getRelationship(),
            guardian.getFullName(),
            guardian.getSecondName(),
            guardian.getSecondLastName(),
            guardian.getDocumentType(),
            guardian.getDocumentNumber(),
            guardian.getPhone(),
            guardian.getLandline(),
            guardian.getCellphone(),
            guardian.getEmail(),
            guardian.getAffiliationRegime(),
            guardian.getInsurer(),
            guardian.getInsurerCode(),
            guardian.getEthnicity(),
            guardian.getDisplaced()))
        .toList();

    List<PatientResponse.MedicalHistoryDto> historyDtos = medicalHistories.stream()
        .map(history -> new PatientResponse.MedicalHistoryDto(
            history.getId(),
            history.getCondition(),
            history.getDiagnosedAt(),
            history.getNotes(),
            history.isHasContraindication(),
            history.getContraindicationDetails(),
            history.isHasPreviousReaction(),
            history.getReactionDetails(),
            history.getHistoryType(),
            history.getSpecialObservations()))
        .toList();

    PatientResponse.AffiliationDto affiliationDto = affiliation == null
        ? null
        : new PatientResponse.AffiliationDto(
            affiliation.getAffiliationRegime(),
            affiliation.getInsurer(),
            affiliation.getInsurerCode());

    PatientResponse.SpecialConditionsDto specialDto = specialConditions == null
        ? null
        : new PatientResponse.SpecialConditionsDto(
            specialConditions.isDisplaced(),
            specialConditions.isDisabled(),
            specialConditions.isDeceased(),
            specialConditions.isArmedConflictVictim(),
            specialConditions.getCurrentlyStudying());

    PatientResponse.UserConditionDto userDto = userCondition == null
        ? null
        : new PatientResponse.UserConditionDto(
            userCondition.getUserCondition(),
            userCondition.getLastMenstrualDate(),
            userCondition.getGestationWeeks(),
            userCondition.getProbableDeliveryDate(),
            userCondition.getPreviousPregnancies(),
            userCondition.getHasGivenBirth(),
            userCondition.getBirthPlaceDelivery());

    return new PatientResponse(
        patient.getId(),
        patient.getInstitutionId(),
        patient.getDocumentType(),
        patient.getDocumentNumber(),
        patient.getFirstName(),
        patient.getSecondName(),
        patient.getLastName(),
        patient.getSecondLastName(),
        patient.getBirthDate(),
        patient.getSex().name(),
        patient.getBirthCountryId(),
        patient.getBirthPlace(),
        patient.getMigrationStatus(),
        patient.getGestationalAgeAtBirth(),
        patient.getVaccinationCardType(),
        patient.isAuthorizeCalls(),
        patient.isAuthorizeEmail(),
        patient.getStatus().name(),
        patient.getVersion(),
        patient.getCreatedAt(),
        patient.getUpdatedAt(),
        demographicDto,
        contactDtos,
        addressDtos,
        guardianDtos,
        historyDtos,
        affiliationDto,
        specialDto,
        userDto);
  }
}
