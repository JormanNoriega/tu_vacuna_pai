package com.pai.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.catalog.dto.CloneCatalogResponse;
import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionTemplateEntity;
import com.pai.api.catalog.repository.InstitutionVaccineOptionRepository;
import com.pai.api.catalog.repository.InstitutionVaccineRepository;
import com.pai.api.catalog.repository.VaccineOptionTemplateRepository;
import com.pai.api.catalog.repository.VaccineRepository;
import com.pai.api.catalog.service.CatalogMapper;
import com.pai.api.catalog.service.InstitutionVaccineService;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.shared.security.PermissionGuard;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class InstitutionVaccineServiceCloneTest {

  private static final UUID ACTOR = UUID.randomUUID();
  private static final UUID INSTITUTION = UUID.randomUUID();

  private InstitutionVaccineRepository relations;
  private InstitutionVaccineOptionRepository local;
  private VaccineRepository vaccines;
  private VaccineOptionTemplateRepository templates;
  private DataScope scope;
  private PermissionGuard guard;
  private InstitutionVaccineService service;

  @BeforeEach
  void setUp() {
    relations = mock(InstitutionVaccineRepository.class);
    local = mock(InstitutionVaccineOptionRepository.class);
    vaccines = mock(VaccineRepository.class);
    templates = mock(VaccineOptionTemplateRepository.class);
    IdentityService identity = mock(IdentityService.class);
    scope = mock(DataScope.class);
    guard = new PermissionGuard(identity);
    service = new InstitutionVaccineService(
        relations, local, vaccines, templates, scope, guard, new CatalogMapper());
    when(identity.resolve(ACTOR))
        .thenReturn(new AuthorizedUser(
            ACTOR,
            "super@pai.test",
            "Super Admin",
            institution(),
            List.of("SUPER_ADMIN"),
            List.of("CATALOG_CONFIG_READ", "CATALOG_CONFIG_WRITE"),
            Instant.now()));
    when(scope.resolveInstitutionId(any(), any())).thenReturn(INSTITUTION);
  }

  @Test
  void cloneWithDefaultConfigCreatesRelationsAndCopiesOptions() {
    VaccineEntity v1 = vaccine("VAC-1");
    VaccineEntity v2 = vaccine("VAC-2");
    when(vaccines.findByActiveTrueOrderByNameAsc()).thenReturn(List.of(v1, v2));
    when(relations.insertEnabledIfAbsent(INSTITUTION, v1.getId(), ACTOR)).thenReturn(1);
    when(relations.insertEnabledIfAbsent(INSTITUTION, v2.getId(), ACTOR)).thenReturn(1);
    when(templates.findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(v1.getId()))
        .thenReturn(List.of(template(v1.getId(), "laboratory"), template(v1.getId(), "syringe")));
    when(templates.findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(v2.getId()))
        .thenReturn(List.of());

    CloneCatalogResponse result = service.clone(ACTOR, INSTITUTION, true);

    assertThat(result.vaccinesEnabled()).isEqualTo(2);
    assertThat(result.optionsCopied()).isEqualTo(2);
    assertThat(result.vaccinesTotal()).isEqualTo(2);
    verify(local, times(2)).save(any(InstitutionVaccineOptionEntity.class));
  }

  @Test
  void cloneWithoutDefaultConfigSkipsOptions() {
    VaccineEntity v1 = vaccine("VAC-1");
    when(vaccines.findByActiveTrueOrderByNameAsc()).thenReturn(List.of(v1));
    when(relations.insertEnabledIfAbsent(INSTITUTION, v1.getId(), ACTOR)).thenReturn(1);

    CloneCatalogResponse result = service.clone(ACTOR, INSTITUTION, false);

    assertThat(result.vaccinesEnabled()).isEqualTo(1);
    assertThat(result.optionsCopied()).isZero();
    verify(local, never()).save(any(InstitutionVaccineOptionEntity.class));
  }

  @Test
  void cloneIsIdempotentForAlreadyEnabledVaccines() {
    VaccineEntity v1 = vaccine("VAC-1");
    when(vaccines.findByActiveTrueOrderByNameAsc()).thenReturn(List.of(v1));
    when(relations.insertEnabledIfAbsent(INSTITUTION, v1.getId(), ACTOR)).thenReturn(0);
    InstitutionVaccineEntity enabled = mock(InstitutionVaccineEntity.class);
    when(enabled.isEnabled()).thenReturn(true);
    when(relations.findByInstitutionIdAndVaccineId(INSTITUTION, v1.getId()))
        .thenReturn(Optional.of(enabled));

    CloneCatalogResponse result = service.clone(ACTOR, INSTITUTION, true);

    assertThat(result.vaccinesEnabled()).isZero();
    assertThat(result.optionsCopied()).isZero();
    verify(local, never()).save(any(InstitutionVaccineOptionEntity.class));
    verify(relations, never()).setEnabledById(any(), anyBoolean());
  }

  @Test
  void cloneRespectsDisabledRelationWithoutTouchingIt() {
    VaccineEntity v1 = vaccine("VAC-1");
    when(vaccines.findByActiveTrueOrderByNameAsc()).thenReturn(List.of(v1));
    when(relations.insertEnabledIfAbsent(INSTITUTION, v1.getId(), ACTOR)).thenReturn(0);

    CloneCatalogResponse result = service.clone(ACTOR, INSTITUTION, true);

    assertThat(result.vaccinesEnabled()).isZero();
    assertThat(result.optionsCopied()).isZero();
    verify(local, never()).save(any(InstitutionVaccineOptionEntity.class));
    // La relacion deshabilitada NO se reactiva: el re-clone respeta la
    // decision de la institucion y no pisa su configuracion local.
    verify(relations, never()).setEnabledById(any(), anyBoolean());
    verify(relations, never()).findByInstitutionIdAndVaccineId(any(), any());
  }

  @Test
  void availableExcludesVaccinesAlreadyRelatedToInstitution() {
    VaccineEntity v1 = vaccine("VAC-1");
    VaccineEntity v2 = vaccine("VAC-2");
    when(vaccines.findByActiveTrueOrderByNameAsc()).thenReturn(List.of(v1, v2));
    InstitutionVaccineEntity existing = mock(InstitutionVaccineEntity.class);
    when(existing.getVaccineId()).thenReturn(v1.getId());
    when(relations.findByInstitutionId(INSTITUTION)).thenReturn(List.of(existing));

    var result = service.available(ACTOR, INSTITUTION);

    assertThat(result).hasSize(1);
    assertThat(result.get(0).id()).isEqualTo(v2.getId());
    assertThat(result.get(0).code()).isEqualTo(v2.getCode());
  }

  private VaccineEntity vaccine(String code) {
    return new VaccineEntity(
        UUID.randomUUID(), "V " + code, code, "PAI", (short) 3, null, null, ACTOR, Instant.now());
  }

  private VaccineOptionTemplateEntity template(UUID vaccineId, String type) {
    return new VaccineOptionTemplateEntity(
        UUID.randomUUID(), vaccineId, type, "valor", "Valor", 0, false, ACTOR, Instant.now());
  }

  private InstitutionEntity institution() {
    return new InstitutionEntity(
        UUID.randomUUID(),
        "PAI-DEMO",
        "Institucion Demo PAI",
        InstitutionEntity.Status.ACTIVE,
        (short) 72,
        Instant.now(),
        Instant.now());
  }
}
