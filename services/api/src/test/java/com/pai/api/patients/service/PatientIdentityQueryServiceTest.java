package com.pai.api.patients.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.catalog.entity.GeoDepartmentEntity;
import com.pai.api.catalog.entity.GeoMunicipalityEntity;
import com.pai.api.catalog.repository.GeoDepartmentRepository;
import com.pai.api.catalog.repository.GeoMunicipalityRepository;
import com.pai.api.patients.entity.PatientAddressEntity;
import com.pai.api.patients.entity.PatientDemographicEntity;
import com.pai.api.patients.entity.PatientEntity;
import com.pai.api.patients.entity.PatientEntity.Sex;
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
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class PatientIdentityQueryServiceTest {

  private PatientRepository patients;
  private PatientDemographicRepository demographics;
  private PatientAddressRepository addresses;
  private PatientAffiliationRepository affiliations;
  private PatientSpecialConditionRepository specialConditions;
  private PatientUserConditionRepository userConditions;
  private PatientMedicalHistoryRepository medicalHistories;
  private PatientGuardianRepository guardians;
  private PatientContactRepository contacts;
  private GeoDepartmentRepository geoDepartments;
  private GeoMunicipalityRepository geoMunicipalities;

  private PatientIdentityQueryService service;

  @BeforeEach
  void setUp() {
    patients = mock(PatientRepository.class);
    demographics = mock(PatientDemographicRepository.class);
    addresses = mock(PatientAddressRepository.class);
    affiliations = mock(PatientAffiliationRepository.class);
    specialConditions = mock(PatientSpecialConditionRepository.class);
    userConditions = mock(PatientUserConditionRepository.class);
    medicalHistories = mock(PatientMedicalHistoryRepository.class);
    guardians = mock(PatientGuardianRepository.class);
    contacts = mock(PatientContactRepository.class);
    geoDepartments = mock(GeoDepartmentRepository.class);
    geoMunicipalities = mock(GeoMunicipalityRepository.class);

    service =
        new PatientIdentityQueryService(
            patients,
            demographics,
            addresses,
            affiliations,
            specialConditions,
            userConditions,
            medicalHistories,
            guardians,
            contacts,
            geoDepartments,
            geoMunicipalities);
  }

  @Test
  void resolvesDepartmentAndMunicipalityNamesDistinctFromLocality() {
    UUID patientId = UUID.randomUUID();
    UUID countryId = UUID.randomUUID();
    UUID depId = UUID.randomUUID();
    UUID munId = UUID.randomUUID();

    PatientEntity patient =
        new PatientEntity(
            patientId,
            UUID.randomUUID(),
            "CC",
            "1003239695",
            "JULIO",
            "RIOS",
            LocalDate.of(2003, 5, 2),
            Sex.MALE,
            Instant.now());

    when(patients.findAllById(List.of(patientId))).thenReturn(List.of(patient));

    PatientAddressEntity address =
        new PatientAddressEntity(
            UUID.randomUUID(),
            patientId,
            "Calle 16 # 19-20",
            munId,
            depId,
            countryId,
            "San Martín",
            "URBANA",
            true,
            Instant.now());

    when(addresses.findByPatientIdInOrderByCreatedAtAsc(anyCollection()))
        .thenReturn(List.of(address));

    GeoDepartmentEntity cesar = new GeoDepartmentEntity(depId, countryId, "20", "CESAR");
    when(geoDepartments.findAllById(anyCollection())).thenReturn(List.of(cesar));

    GeoMunicipalityEntity valledupar =
        new GeoMunicipalityEntity(munId, depId, "20001", "VALLEDUPAR");
    when(geoMunicipalities.findAllById(anyCollection())).thenReturn(List.of(valledupar));

    when(demographics.findAllById(anyCollection())).thenReturn(List.of());
    when(affiliations.findAllById(anyCollection())).thenReturn(List.of());
    when(specialConditions.findAllById(anyCollection())).thenReturn(List.of());
    when(userConditions.findAllById(anyCollection())).thenReturn(List.of());
    when(medicalHistories.findByPatientIdInOrderByCreatedAtAsc(anyCollection())).thenReturn(List.of());
    when(guardians.findByPatientIdInOrderByCreatedAtAsc(anyCollection())).thenReturn(List.of());
    when(contacts.findByPatientIdInOrderByCreatedAtAsc(anyCollection())).thenReturn(List.of());

    List<PatientIdentity> result = service.byIds(List.of(patientId));

    assertThat(result).hasSize(1);
    PatientIdentity identity = result.get(0);
    assertThat(identity.residenceCountry()).isEqualTo("COLOMBIA");
    assertThat(identity.residenceDepartment()).isEqualTo("CESAR");
    assertThat(identity.residenceMunicipality()).isEqualTo("VALLEDUPAR");
    assertThat(identity.commune()).isEqualTo("San Martín");
    assertThat(identity.area()).isEqualTo("URBANA");
    assertThat(identity.address()).isEqualTo("Calle 16 # 19-20");
  }
}
