package com.pai.api.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.identity.dto.CreateInstitutionRequest;
import com.pai.api.identity.dto.InstitutionResponse;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.exception.InstitutionCodeAlreadyExistsException;
import com.pai.api.identity.exception.InstitutionNotFoundException;
import com.pai.api.identity.repository.InstitutionRepository;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class InstitutionServiceTest {

  private static final UUID ACTOR_ID = UUID.randomUUID();

  private InstitutionRepository institutionRepository;
  private InstitutionCatalogSeeder catalogSeeder;
  private InstitutionService service;

  @BeforeEach
  void setUp() {
    institutionRepository = mock(InstitutionRepository.class);
    catalogSeeder = mock(InstitutionCatalogSeeder.class);
    service = new InstitutionService(institutionRepository, catalogSeeder);
  }

  @Test
  void create_savesActiveInstitutionWithDefaults() {
    when(institutionRepository.findByCode("HOSP-A")).thenReturn(Optional.empty());
    when(institutionRepository.save(any(InstitutionEntity.class)))
        .thenAnswer(inv -> inv.getArgument(0));

    InstitutionResponse result =
        service.create(ACTOR_ID, new CreateInstitutionRequest(" hosp-a ", " Hospital A ", null));

    assertThat(result.code()).isEqualTo("HOSP-A");
    assertThat(result.name()).isEqualTo("Hospital A");
    assertThat(result.status()).isEqualTo("ACTIVE");
    assertThat(result.offlineWindowHours()).isEqualTo((short) 72);
    verify(institutionRepository).save(any(InstitutionEntity.class));
  }

  @Test
  void create_seedsInstitutionCatalog() {
    when(institutionRepository.findByCode("HOSP-A")).thenReturn(Optional.empty());
    when(institutionRepository.save(any(InstitutionEntity.class)))
        .thenAnswer(inv -> inv.getArgument(0));

    InstitutionResponse result =
        service.create(ACTOR_ID, new CreateInstitutionRequest("HOSP-A", "Hospital A", null));

    verify(catalogSeeder).seed(result.id(), ACTOR_ID);
  }

  @Test
  void create_usesProvidedOfflineWindow() {
    when(institutionRepository.findByCode("HOSP-A")).thenReturn(Optional.empty());
    when(institutionRepository.save(any(InstitutionEntity.class)))
        .thenAnswer(inv -> inv.getArgument(0));

    InstitutionResponse result =
        service.create(ACTOR_ID, new CreateInstitutionRequest("HOSP-A", "Hospital A", (short) 48));

    assertThat(result.offlineWindowHours()).isEqualTo((short) 48);
  }

  @Test
  void create_rejectsDuplicateCode() {
    when(institutionRepository.findByCode("HOSP-A")).thenReturn(Optional.of(entity("HOSP-A")));

    assertThatThrownBy(() ->
            service.create(ACTOR_ID, new CreateInstitutionRequest("HOSP-A", "Hospital A", null)))
        .isInstanceOf(InstitutionCodeAlreadyExistsException.class);
    verify(institutionRepository, never()).save(any(InstitutionEntity.class));
  }

  @Test
  void list_returnsAllInstitutionsOrdered() {
    when(institutionRepository.findAllByOrderByNameAsc())
        .thenReturn(List.of(entity("HOSP-A"), entity("HOSP-B")));

    List<InstitutionResponse> result = service.list();

    assertThat(result).hasSize(2);
  }

  @Test
  void updateStatus_activatesOrDeactivates() {
    InstitutionEntity entity = entity("HOSP-A");
    when(institutionRepository.findById(entity.getId())).thenReturn(Optional.of(entity));
    when(institutionRepository.save(any(InstitutionEntity.class)))
        .thenAnswer(inv -> inv.getArgument(0));

    InstitutionResponse result = service.updateStatus(entity.getId(), "INACTIVE");

    assertThat(result.status()).isEqualTo("INACTIVE");
  }

  @Test
  void updateStatus_throwsWhenInstitutionMissing() {
    UUID id = UUID.randomUUID();
    when(institutionRepository.findById(id)).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.updateStatus(id, "ACTIVE"))
        .isInstanceOf(InstitutionNotFoundException.class);
  }

  @Test
  void updateStatus_rejectsInvalidStatus() {
    InstitutionEntity entity = entity("HOSP-A");
    when(institutionRepository.findById(entity.getId())).thenReturn(Optional.of(entity));

    assertThatThrownBy(() -> service.updateStatus(entity.getId(), "BANANA"))
        .isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  void updateConfig_updatesOfflineWindow() {
    InstitutionEntity entity = entity("HOSP-A");
    when(institutionRepository.findById(entity.getId())).thenReturn(Optional.of(entity));
    when(institutionRepository.save(any(InstitutionEntity.class)))
        .thenAnswer(inv -> inv.getArgument(0));

    InstitutionResponse result = service.updateConfig(entity.getId(), (short) 48);

    assertThat(result.offlineWindowHours()).isEqualTo((short) 48);
  }

  @Test
  void updateConfig_throwsWhenInstitutionMissing() {
    UUID id = UUID.randomUUID();
    when(institutionRepository.findById(id)).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.updateConfig(id, (short) 48))
        .isInstanceOf(InstitutionNotFoundException.class);
  }

  @Test
  void updateConfig_rejectsOutOfRange() {
    InstitutionEntity entity = entity("HOSP-A");
    when(institutionRepository.findById(entity.getId())).thenReturn(Optional.of(entity));

    assertThatThrownBy(() -> service.updateConfig(entity.getId(), (short) 0))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> service.updateConfig(entity.getId(), (short) 200))
        .isInstanceOf(IllegalArgumentException.class);
  }

  private InstitutionEntity entity(String code) {
    return new InstitutionEntity(
        UUID.randomUUID(),
        code,
        "Inst " + code,
        InstitutionEntity.Status.ACTIVE,
        (short) 72,
        Instant.now(),
        Instant.now());
  }
}
