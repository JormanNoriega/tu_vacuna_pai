package com.pai.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.catalog.dto.HealthInsurerResponse;
import com.pai.api.catalog.entity.HealthInsurerEntity;
import com.pai.api.catalog.repository.HealthInsurerRepository;
import com.pai.api.catalog.service.HealthInsurerService;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class HealthInsurerServiceTest {

  private HealthInsurerRepository repository;
  private HealthInsurerService service;

  @BeforeEach
  void setUp() {
    repository = mock(HealthInsurerRepository.class);
    service = new HealthInsurerService(repository);
  }

  private static HealthInsurerEntity insurer() {
    HealthInsurerEntity entity = mock(HealthInsurerEntity.class);
    UUID id = UUID.randomUUID();
    when(entity.getId()).thenReturn(id);
    when(entity.getNit()).thenReturn("900156264");
    when(entity.getName()).thenReturn("Nueva EPS");
    when(entity.getCode()).thenReturn("EPS037 - EPSS41");
    when(entity.getRegime()).thenReturn("AMBOS");
    return entity;
  }

  @Test
  void list_returnsAllActiveWhenNoRegime() {
    HealthInsurerEntity entity = insurer();
    when(repository.findByActiveTrueOrderByNameAsc()).thenReturn(List.of(entity));

    List<HealthInsurerResponse> result = service.list(null);

    assertThat(result).hasSize(1);
    assertThat(result.get(0).nit()).isEqualTo("900156264");
    assertThat(result.get(0).name()).isEqualTo("Nueva EPS");
    assertThat(result.get(0).regime()).isEqualTo("AMBOS");
  }

  @Test
  void list_filtersByRegimeIncludingAmbos() {
    HealthInsurerEntity entity = insurer();
    when(repository.findByActiveTrueAndRegimeInOrderByNameAsc(Set.of("SUBSIDIADO", "AMBOS")))
        .thenReturn(List.of(entity));

    List<HealthInsurerResponse> result = service.list("subsidiado");

    assertThat(result).hasSize(1);
    verify(repository).findByActiveTrueAndRegimeInOrderByNameAsc(Set.of("SUBSIDIADO", "AMBOS"));
  }
}
