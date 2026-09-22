package com.pai.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.catalog.dto.EffectiveCatalogResponse;
import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionEntity;
import com.pai.api.catalog.repository.InstitutionVaccineOptionRepository;
import com.pai.api.catalog.repository.InstitutionVaccineRepository;
import com.pai.api.catalog.repository.VaccineOptionRepository;
import com.pai.api.catalog.repository.VaccineRepository;
import com.pai.api.catalog.service.CatalogMapper;
import com.pai.api.catalog.service.EffectiveCatalogService;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class EffectiveCatalogServiceTest {

  private static final UUID ACTOR_ID = UUID.randomUUID();
  private static final UUID INSTITUTION_ID = UUID.randomUUID();

  private InstitutionVaccineRepository institutionVaccines;
  private InstitutionVaccineOptionRepository institutionOptions;
  private VaccineRepository vaccines;
  private VaccineOptionRepository vaccineOptions;
  private IdentityService identity;
  private EffectiveCatalogService service;

  @BeforeEach
  void setUp() {
    institutionVaccines = mock(InstitutionVaccineRepository.class);
    institutionOptions = mock(InstitutionVaccineOptionRepository.class);
    vaccines = mock(VaccineRepository.class);
    vaccineOptions = mock(VaccineOptionRepository.class);
    identity = mock(IdentityService.class);
    service = new EffectiveCatalogService(
        institutionVaccines,
        institutionOptions,
        vaccines,
        vaccineOptions,
        identity,
        new DataScope(),
        new CatalogMapper());
  }

  private InstitutionEntity institution() {
    return new InstitutionEntity(
        INSTITUTION_ID,
        "HOSP-A",
        "Hospital A",
        InstitutionEntity.Status.ACTIVE,
        (short) 72,
        Instant.now(),
        Instant.now());
  }

  private AuthorizedUser actor() {
    return new AuthorizedUser(
        ACTOR_ID,
        "vac@hosp.a",
        "Ana Vacunadora",
        institution(),
        List.of("VACCINATOR"),
        List.of("CATALOG_GLOBAL_READ", "CATALOG_CONFIG_READ"),
        Instant.now());
  }

  private InstitutionVaccineEntity enabledRelation(UUID vaccineId) {
    InstitutionVaccineEntity relation = mock(InstitutionVaccineEntity.class);
    when(relation.isEnabled()).thenReturn(true);
    when(relation.getVaccineId()).thenReturn(vaccineId);
    return relation;
  }

  private VaccineEntity vaccine(UUID id, String name, String code) {
    return new VaccineEntity(id, name, code, "PAI", (short) 1, null, null, ACTOR_ID, Instant.now());
  }

  private VaccineOptionEntity dose(UUID vaccineId, String displayName) {
    return new VaccineOptionEntity(
        UUID.randomUUID(), vaccineId, "dose", "1", displayName, 0, true, ACTOR_ID, Instant.now());
  }

  private InstitutionVaccineOptionEntity operational(UUID vaccineId, String displayName) {
    return new InstitutionVaccineOptionEntity(
        UUID.randomUUID(),
        INSTITUTION_ID,
        vaccineId,
        "laboratory",
        displayName,
        displayName,
        0,
        false,
        null,
        ACTOR_ID,
        Instant.now());
  }

  private void givenBatchedOptions(
      List<VaccineOptionEntity> doses, List<InstitutionVaccineOptionEntity> operational) {
    when(vaccineOptions.findByVaccineIdInAndActiveTrueOrderByVaccineIdAscSortOrderAscDisplayNameAsc(
            any()))
        .thenReturn(doses);
    when(institutionOptions
            .findByInstitutionIdAndVaccineIdInAndActiveTrueOrderByVaccineIdAscSortOrderAscDisplayNameAsc(
                any(), any()))
        .thenReturn(operational);
  }

  @Test
  void list_includesEnabledVaccineWithDosesAndOperationalOptions() {
    UUID vaccineId = UUID.randomUUID();
    when(identity.resolve(ACTOR_ID)).thenReturn(actor());
    InstitutionVaccineEntity relation = enabledRelation(vaccineId);
    when(institutionVaccines.findByInstitutionId(INSTITUTION_ID)).thenReturn(List.of(relation));
    when(vaccines.findAllById(any())).thenReturn(List.of(vaccine(vaccineId, "Influenza", "INF")));
    givenBatchedOptions(
        List.of(dose(vaccineId, "Primera dosis")), List.of(operational(vaccineId, "Pfizer")));

    EffectiveCatalogResponse response = service.list(ACTOR_ID);

    assertThat(response.vaccines()).hasSize(1);
    EffectiveCatalogResponse.EffectiveVaccine effective = response.vaccines().get(0);
    assertThat(effective.name()).isEqualTo("Influenza");
    assertThat(effective.doses()).hasSize(1);
    assertThat(effective.doses().get(0).displayName()).isEqualTo("Primera dosis");
    assertThat(effective.operationalOptions()).hasSize(1);
    assertThat(effective.operationalOptions().get(0).displayName()).isEqualTo("Pfizer");
  }

  @Test
  void list_excludesDisabledVaccines() {
    when(identity.resolve(ACTOR_ID)).thenReturn(actor());
    InstitutionVaccineEntity disabled = mock(InstitutionVaccineEntity.class);
    when(disabled.isEnabled()).thenReturn(false);
    when(institutionVaccines.findByInstitutionId(INSTITUTION_ID)).thenReturn(List.of(disabled));

    EffectiveCatalogResponse response = service.list(ACTOR_ID);

    assertThat(response.vaccines()).isEmpty();
  }

  @Test
  void list_groupsOptionsPerVaccineWhenBatched() {
    UUID first = UUID.randomUUID();
    UUID second = UUID.randomUUID();
    when(identity.resolve(ACTOR_ID)).thenReturn(actor());
    InstitutionVaccineEntity firstRelation = enabledRelation(first);
    InstitutionVaccineEntity secondRelation = enabledRelation(second);
    when(institutionVaccines.findByInstitutionId(INSTITUTION_ID))
        .thenReturn(List.of(firstRelation, secondRelation));
    when(vaccines.findAllById(any()))
        .thenReturn(List.of(vaccine(first, "Influenza", "INF"), vaccine(second, "Polio", "POL")));
    givenBatchedOptions(
        List.of(dose(first, "Influenza 1"), dose(second, "Polio 1")),
        List.of(operational(first, "Pfizer")));

    EffectiveCatalogResponse response = service.list(ACTOR_ID);

    assertThat(response.vaccines()).hasSize(2);
    EffectiveCatalogResponse.EffectiveVaccine influenza = response.vaccines().get(0);
    EffectiveCatalogResponse.EffectiveVaccine polio = response.vaccines().get(1);
    assertThat(influenza.name()).isEqualTo("Influenza");
    assertThat(influenza.doses())
        .extracting(EffectiveCatalogResponse.OptionItem::displayName)
        .containsExactly("Influenza 1");
    assertThat(influenza.operationalOptions()).hasSize(1);
    assertThat(polio.name()).isEqualTo("Polio");
    assertThat(polio.doses())
        .extracting(EffectiveCatalogResponse.OptionItem::displayName)
        .containsExactly("Polio 1");
    assertThat(polio.operationalOptions()).isEmpty();
  }
}
