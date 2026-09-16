package com.pai.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.catalog.entity.HealthInsurerEntity;
import com.pai.api.catalog.repository.HealthInsurerRepository;
import com.pai.api.catalog.service.HealthInsurerImporter;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class HealthInsurerImporterTest {

  private HealthInsurerRepository repository;
  private HealthInsurerImporter importer;
  private final Map<String, HealthInsurerEntity> store = new HashMap<>();

  @BeforeEach
  void setUp() {
    store.clear();
    repository = mock(HealthInsurerRepository.class);
    when(repository.findByNit(anyString()))
        .thenAnswer(invocation -> Optional.ofNullable(store.get(invocation.getArgument(0))));
    when(repository.save(any(HealthInsurerEntity.class))).thenAnswer(invocation -> {
      HealthInsurerEntity entity = invocation.getArgument(0);
      store.put(entity.getNit(), entity);
      return entity;
    });
    importer = new HealthInsurerImporter(repository);
  }

  @Test
  void seedsAllInsurersFromJsonWhenCatalogIsEmpty() throws Exception {
    importer.run(null);

    assertThat(store).hasSize(28);
    assertThat(store.get("900156264").getName()).isEqualTo("Nueva EPS");
    assertThat(store.get("900156264").getRegime()).isEqualTo("AMBOS");
    assertThat(store.get("830113831").getRegime()).isEqualTo("CONTRIBUTIVO");
    verify(repository, times(28)).save(any(HealthInsurerEntity.class));
  }

  @Test
  void isIdempotentAndDoesNotResaveUnchangedInsurers() throws Exception {
    importer.run(null);
    importer.run(null);

    assertThat(store).hasSize(28);
    // La segunda corrida no reescribe: los valores coinciden con el seed.
    verify(repository, times(28)).save(any(HealthInsurerEntity.class));
  }
}
