package com.pai.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.attentions.exception.InvalidCatalogSelectionException;
import com.pai.api.attentions.service.VaccineCatalogPolicy.DoseSelection;
import com.pai.api.attentions.service.VaccineCatalogPolicy.ResolutionRequest;
import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionEntity;
import com.pai.api.catalog.repository.InstitutionVaccineOptionRepository;
import com.pai.api.catalog.repository.InstitutionVaccineRepository;
import com.pai.api.catalog.repository.VaccineOptionRepository;
import com.pai.api.catalog.repository.VaccineRepository;
import com.pai.api.catalog.service.CatalogSelectionService;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class CatalogSelectionServiceTest {

  private static final UUID ACTOR = UUID.randomUUID();
  private static final UUID INSTITUTION = UUID.randomUUID();
  private static final UUID VACCINE = UUID.randomUUID();

  private VaccineRepository vaccines;
  private VaccineOptionRepository vaccineOptions;
  private InstitutionVaccineRepository institutionVaccines;
  private InstitutionVaccineOptionRepository institutionOptions;
  private CatalogSelectionService service;

  @BeforeEach
  void setUp() {
    vaccines = mock(VaccineRepository.class);
    vaccineOptions = mock(VaccineOptionRepository.class);
    institutionVaccines = mock(InstitutionVaccineRepository.class);
    institutionOptions = mock(InstitutionVaccineOptionRepository.class);
    service = new CatalogSelectionService(
        vaccines, vaccineOptions, institutionVaccines, institutionOptions);
  }

  private VaccineEntity vaccine() {
    return new VaccineEntity(
        VACCINE, "Influenza", "INF", "PAI", (short) 1, null, null, ACTOR, Instant.now());
  }

  private VaccineOptionEntity globalOption(String fieldType, UUID id) {
    return new VaccineOptionEntity(
        id, VACCINE, fieldType, "valor", "Dosis 1", 0, true, ACTOR, Instant.now());
  }

  private InstitutionVaccineOptionEntity institutionOption(String fieldType, UUID id) {
    return new InstitutionVaccineOptionEntity(
        id,
        INSTITUTION,
        VACCINE,
        fieldType,
        "valor",
        "Pfizer",
        0,
        false,
        null,
        ACTOR,
        Instant.now());
  }

  private ResolutionRequest request(UUID dose, UUID pneumo) {
    return new ResolutionRequest(
        INSTITUTION,
        VACCINE,
        dose,
        pneumo,
        institutionOptionId("laboratory"),
        institutionOptionId("syringe"),
        institutionOptionId("dropper"),
        institutionOptionId("observation"));
  }

  private UUID institutionOptionId(String fieldType) {
    return UUID.nameUUIDFromBytes(fieldType.getBytes());
  }

  private void givenEnabledVaccine() {
    when(vaccines.findById(VACCINE)).thenReturn(Optional.of(vaccine()));
    InstitutionVaccineEntity relation = mock(InstitutionVaccineEntity.class);
    when(relation.isEnabled()).thenReturn(true);
    when(institutionVaccines.findByInstitutionIdAndVaccineId(INSTITUTION, VACCINE))
        .thenReturn(Optional.of(relation));
  }

  private void givenInstitutionalOption(String fieldType, UUID id) {
    when(institutionOptions.findByIdAndInstitutionIdAndVaccineId(id, INSTITUTION, VACCINE))
        .thenReturn(Optional.of(institutionOption(fieldType, id)));
  }

  @Test
  void resolve_buildsSnapshotWithDoseAndPneumoAndOperationalOptions() {
    givenEnabledVaccine();
    UUID dose = UUID.randomUUID();
    UUID pneumo = UUID.randomUUID();
    when(vaccineOptions.findByIdAndVaccineId(dose, VACCINE))
        .thenReturn(Optional.of(globalOption("dose", dose)));
    when(vaccineOptions.findByIdAndVaccineId(pneumo, VACCINE))
        .thenReturn(Optional.of(globalOption("pneumococcalType", pneumo)));
    givenInstitutionalOption("laboratory", institutionOptionId("laboratory"));
    givenInstitutionalOption("syringe", institutionOptionId("syringe"));
    givenInstitutionalOption("dropper", institutionOptionId("dropper"));
    givenInstitutionalOption("observation", institutionOptionId("observation"));

    DoseSelection selection = service.resolve(request(dose, pneumo));

    assertThat(selection.vaccineId()).isEqualTo(VACCINE);
    assertThat(selection.vaccineName()).isEqualTo("Influenza");
    assertThat(selection.vaccineCode()).isEqualTo("INF");
    assertThat(selection.doseOptionId()).isEqualTo(dose);
    assertThat(selection.pneumococcalTypeOptionId()).isEqualTo(pneumo);
    assertThat(selection.laboratoryId()).isEqualTo(institutionOptionId("laboratory"));
    assertThat(selection.laboratorySnapshot()).isEqualTo("Pfizer");
  }

  @Test
  void resolve_rejectsVaccineNotEnabledInInstitution() {
    when(vaccines.findById(VACCINE)).thenReturn(Optional.of(vaccine()));
    when(institutionVaccines.findByInstitutionIdAndVaccineId(INSTITUTION, VACCINE))
        .thenReturn(Optional.of(mock(InstitutionVaccineEntity.class)));

    assertThatThrownBy(() -> service.resolve(request(UUID.randomUUID(), null)))
        .isInstanceOf(InvalidCatalogSelectionException.class);
  }

  @Test
  void resolve_rejectsInactiveVaccine() {
    VaccineEntity inactive = mock(VaccineEntity.class);
    when(inactive.isActive()).thenReturn(false);
    when(vaccines.findById(VACCINE)).thenReturn(Optional.of(inactive));

    assertThatThrownBy(() -> service.resolve(request(UUID.randomUUID(), null)))
        .isInstanceOf(InvalidCatalogSelectionException.class);
  }

  @Test
  void resolve_rejectsDoseOptionWithWrongType() {
    givenEnabledVaccine();
    UUID dose = UUID.randomUUID();
    when(vaccineOptions.findByIdAndVaccineId(dose, VACCINE))
        .thenReturn(Optional.of(globalOption("pneumococcalType", dose)));

    assertThatThrownBy(() -> service.resolve(request(dose, null)))
        .isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  void resolve_rejectsInstitutionalOptionWithWrongType() {
    givenEnabledVaccine();
    UUID dose = UUID.randomUUID();
    when(vaccineOptions.findByIdAndVaccineId(dose, VACCINE))
        .thenReturn(Optional.of(globalOption("dose", dose)));
    givenInstitutionalOption("syringe", institutionOptionId("laboratory"));

    assertThatThrownBy(() -> service.resolve(request(dose, null)))
        .isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  void resolve_acceptsNullPneumoAndNullOperationalOptions() {
    givenEnabledVaccine();
    UUID dose = UUID.randomUUID();
    when(vaccineOptions.findByIdAndVaccineId(dose, VACCINE))
        .thenReturn(Optional.of(globalOption("dose", dose)));

    DoseSelection selection = service.resolve(
        new ResolutionRequest(INSTITUTION, VACCINE, dose, null, null, null, null, null));

    assertThat(selection.pneumococcalTypeOptionId()).isNull();
    assertThat(selection.laboratoryId()).isNull();
    assertThat(selection.observationSnapshot()).isNull();
  }
}
