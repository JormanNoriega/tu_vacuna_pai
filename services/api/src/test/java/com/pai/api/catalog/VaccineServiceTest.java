package com.pai.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.catalog.dto.OptionRequest;
import com.pai.api.catalog.dto.OptionResponse;
import com.pai.api.catalog.dto.VaccineResponse;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineOptionTemplateEntity;
import com.pai.api.catalog.exception.OptimisticCatalogException;
import com.pai.api.catalog.repository.VaccineOptionRepository;
import com.pai.api.catalog.repository.VaccineOptionTemplateRepository;
import com.pai.api.catalog.repository.VaccineRepository;
import com.pai.api.catalog.service.CatalogMapper;
import com.pai.api.catalog.service.VaccineService;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.shared.security.PermissionGuard;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class VaccineServiceTest {

  private static final UUID ACTOR_ID = UUID.randomUUID();
  private static final UUID VACCINE_ID = UUID.randomUUID();

  private VaccineRepository vaccines;
  private VaccineOptionRepository options;
  private VaccineOptionTemplateRepository templates;
  private PermissionGuard guard;
  private VaccineService service;

  @BeforeEach
  void setUp() {
    vaccines = mock(VaccineRepository.class);
    options = mock(VaccineOptionRepository.class);
    templates = mock(VaccineOptionTemplateRepository.class);
    guard = mock(PermissionGuard.class);
    service = new VaccineService(vaccines, options, templates, guard, new CatalogMapper());
    when(guard.require(any(), any())).thenReturn(actor());
    when(vaccines.existsById(VACCINE_ID)).thenReturn(true);
  }

  private AuthorizedUser actor() {
    return new AuthorizedUser(
        ACTOR_ID,
        "super@admin.test",
        "Super Admin",
        new InstitutionEntity(
            UUID.randomUUID(),
            "HOSP-A",
            "Hospital A",
            InstitutionEntity.Status.ACTIVE,
            (short) 72,
            Instant.now(),
            Instant.now()),
        List.of("SUPER_ADMIN"),
        List.of("CATALOG_GLOBAL_READ", "CATALOG_GLOBAL_WRITE"),
        Instant.now());
  }

  private OptionRequest request(String fieldType) {
    return new OptionRequest(fieldType, "valor", "Valor", 1, false, true, 0L);
  }

  private VaccineOptionEntity globalOption(String fieldType) {
    return globalOption(fieldType, false);
  }

  private VaccineOptionEntity globalOption(String fieldType, boolean isDefault) {
    return new VaccineOptionEntity(
        UUID.randomUUID(),
        VACCINE_ID,
        fieldType,
        "valor",
        "Valor",
        1,
        isDefault,
        ACTOR_ID,
        Instant.now());
  }

  private VaccineOptionTemplateEntity template(String fieldType) {
    return new VaccineOptionTemplateEntity(
        UUID.randomUUID(),
        VACCINE_ID,
        fieldType,
        "valor",
        "Valor",
        1,
        false,
        ACTOR_ID,
        Instant.now());
  }

  @Test
  void list_returnsActiveVaccines() {
    when(vaccines.findByActiveTrueOrderByNameAsc())
        .thenReturn(List.of(new VaccineEntity(
            VACCINE_ID,
            "Influenza",
            "INF",
            "PAI",
            (short) 1,
            null,
            null,
            ACTOR_ID,
            Instant.now())));

    List<VaccineResponse> result = service.list(ACTOR_ID);

    assertThat(result).singleElement().extracting(VaccineResponse::code).isEqualTo("INF");
  }

  @Test
  void createOption_savesGlobalOption() {
    when(options.save(any(VaccineOptionEntity.class))).thenAnswer(inv -> inv.getArgument(0));

    OptionResponse response = service.createOption(ACTOR_ID, VACCINE_ID, request("dose"));

    assertThat(response.fieldType()).isEqualTo("dose");
    verify(options).save(any(VaccineOptionEntity.class));
  }

  @Test
  void createTemplate_savesTemplate() {
    when(templates.save(any(VaccineOptionTemplateEntity.class)))
        .thenAnswer(inv -> inv.getArgument(0));

    OptionResponse response = service.createTemplate(ACTOR_ID, VACCINE_ID, request("laboratory"));

    assertThat(response.fieldType()).isEqualTo("laboratory");
    verify(templates).save(any(VaccineOptionTemplateEntity.class));
  }

  @Test
  void createOption_rejectsUnknownVaccine() {
    UUID unknown = UUID.randomUUID();
    when(vaccines.existsById(unknown)).thenReturn(false);

    assertThatThrownBy(() -> service.createOption(ACTOR_ID, unknown, request("dose")))
        .isInstanceOf(IllegalArgumentException.class);
    verify(options, never()).save(any());
  }

  @Test
  void createOption_rejectsNonGlobalType() {
    assertThatThrownBy(() -> service.createOption(ACTOR_ID, VACCINE_ID, request("laboratory")))
        .isInstanceOf(IllegalArgumentException.class);
    verify(options, never()).save(any());
  }

  @Test
  void createTemplate_rejectsNonTemplateType() {
    assertThatThrownBy(() -> service.createTemplate(ACTOR_ID, VACCINE_ID, request("dose")))
        .isInstanceOf(IllegalArgumentException.class);
    verify(templates, never()).save(any());
  }

  @Test
  void updateOption_rejectsVersionMismatch() {
    UUID optionId = UUID.randomUUID();
    when(options.findByIdAndVaccineId(optionId, VACCINE_ID))
        .thenReturn(Optional.of(globalOption("dose")));

    OptionRequest stale = new OptionRequest("dose", "valor", "Valor", 1, false, true, 99L);

    assertThatThrownBy(() -> service.updateOption(ACTOR_ID, VACCINE_ID, optionId, stale))
        .isInstanceOf(OptimisticCatalogException.class);
  }

  @Test
  void updateOption_rejectsFieldTypeChange() {
    UUID optionId = UUID.randomUUID();
    when(options.findByIdAndVaccineId(optionId, VACCINE_ID))
        .thenReturn(Optional.of(globalOption("dose")));

    OptionRequest changed =
        new OptionRequest("pneumococcalType", "valor", "Valor", 1, false, true, 0L);

    assertThatThrownBy(() -> service.updateOption(ACTOR_ID, VACCINE_ID, optionId, changed))
        .isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  void updateOption_clearsOtherDefaultsWhenMarkedDefault() {
    UUID optionId = UUID.randomUUID();
    VaccineOptionEntity target = globalOption("dose");
    VaccineOptionEntity other = globalOption("dose", true);
    when(options.findByIdAndVaccineId(optionId, VACCINE_ID)).thenReturn(Optional.of(target));
    when(options.lockActive(VACCINE_ID)).thenReturn(List.of(target, other));
    when(options.save(any(VaccineOptionEntity.class))).thenAnswer(inv -> inv.getArgument(0));

    OptionRequest asDefault = new OptionRequest("dose", "nuevo", "Nuevo", 2, true, true, 0L);
    service.updateOption(ACTOR_ID, VACCINE_ID, optionId, asDefault);

    assertThat(target.isDefault()).isTrue();
    assertThat(other.isDefault()).isFalse();
  }

  @Test
  void deleteOption_marksInactive() {
    UUID optionId = UUID.randomUUID();
    VaccineOptionEntity target = globalOption("dose");
    when(options.findByIdAndVaccineId(optionId, VACCINE_ID)).thenReturn(Optional.of(target));

    service.deleteOption(ACTOR_ID, VACCINE_ID, optionId, 0L);

    assertThat(target.isActive()).isFalse();
  }

  @Test
  void updateTemplate_rejectsVersionMismatch() {
    UUID templateId = UUID.randomUUID();
    when(templates.findByIdAndVaccineId(templateId, VACCINE_ID))
        .thenReturn(Optional.of(template("laboratory")));

    OptionRequest stale = new OptionRequest("laboratory", "valor", "Valor", 1, false, true, 7L);

    assertThatThrownBy(() -> service.updateTemplate(ACTOR_ID, VACCINE_ID, templateId, stale))
        .isInstanceOf(OptimisticCatalogException.class);
  }

  @Test
  void deleteTemplate_marksInactive() {
    UUID templateId = UUID.randomUUID();
    VaccineOptionTemplateEntity target = template("laboratory");
    when(templates.findByIdAndVaccineId(templateId, VACCINE_ID)).thenReturn(Optional.of(target));

    service.deleteTemplate(ACTOR_ID, VACCINE_ID, templateId, 0L);

    assertThat(target.isActive()).isFalse();
  }

  @Test
  void globalOptions_listsActiveOptions() {
    when(options.findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(VACCINE_ID))
        .thenReturn(List.of(globalOption("dose")));

    List<OptionResponse> result = service.globalOptions(ACTOR_ID, VACCINE_ID);

    assertThat(result).singleElement().extracting(OptionResponse::fieldType).isEqualTo("dose");
    verify(guard, never()).require(eq(ACTOR_ID), eq("CATALOG_GLOBAL_WRITE"));
  }
}
