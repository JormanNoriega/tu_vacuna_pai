package com.pai.api.catalog.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.attentions.service.VaccineCatalogPolicy.DoseSelection;
import com.pai.api.attentions.service.VaccineCatalogPolicy.ResolutionRequest;
import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionEntity;
import com.pai.api.catalog.exception.InconsistentFlyweightException;
import com.pai.api.catalog.repository.InstitutionVaccineOptionRepository;
import com.pai.api.catalog.repository.InstitutionVaccineRepository;
import com.pai.api.catalog.repository.VaccineOptionRepository;
import com.pai.api.catalog.repository.VaccineRepository;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Pruebas de integracion del patron Flyweight (PE-04) en el flujo real:
 * el catalogo resuelve la definicion compartida y el warmer precarga el pool.
 */
@DisplayName("Integracion del Flyweight en el flujo de catalogo")
class VaccineFlyweightIntegrationTest {

  private static final UUID ACTOR = UUID.randomUUID();
  private static final UUID INSTITUTION = UUID.randomUUID();
  private static final UUID VACCINE = UUID.randomUUID();

  @Test
  @DisplayName("Dos dosis de la misma vacuna comparten la instancia resuelta por el catalogo")
  void catalogResolutionSharesTheSameFlyweightAcrossDoses() {
    VaccineRepository vaccines = mock(VaccineRepository.class);
    VaccineOptionRepository options = mock(VaccineOptionRepository.class);
    InstitutionVaccineRepository institutionVaccines = mock(InstitutionVaccineRepository.class);
    InstitutionVaccineOptionRepository institutionOptions =
        mock(InstitutionVaccineOptionRepository.class);
    VaccineFlyweightFactory flyweights = new VaccineFlyweightFactory();

    when(vaccines.findById(VACCINE)).thenReturn(Optional.of(vaccine("Influenza", "INF")));
    InstitutionVaccineEntity relation = mock(InstitutionVaccineEntity.class);
    when(relation.isEnabled()).thenReturn(true);
    when(institutionVaccines.findByInstitutionIdAndVaccineId(INSTITUTION, VACCINE))
        .thenReturn(Optional.of(relation));
    UUID dose = UUID.randomUUID();
    when(options.findByIdAndVaccineId(dose, VACCINE))
        .thenReturn(Optional.of(globalOption(dose)));

    CatalogSelectionService service = new CatalogSelectionService(
        vaccines, options, institutionVaccines, institutionOptions, flyweights);

    DoseSelection first = service.resolve(request(dose));
    DoseSelection second = service.resolve(request(dose));

    assertThat(first.vaccine()).isSameAs(second.vaccine());
    assertThat(first.vaccine().getName()).isEqualTo("Influenza");
    assertThat(first.vaccine().getCode()).isEqualTo("INF");
    assertThat(flyweights.getPoolSize()).isEqualTo(1);
  }

  @Test
  @DisplayName("El warmer precarga una sola instancia por vacuna del catalogo")
  void warmerPreloadsOneInstancePerVaccine() {
    VaccineRepository vaccines = mock(VaccineRepository.class);
    VaccineFlyweightFactory flyweights = new VaccineFlyweightFactory();
    VaccineEntity bcg = vaccine("Tuberculosis BCG", "BCG");
    VaccineEntity penta = vaccine("Pentavalente", "PENTA");
    when(vaccines.findAll()).thenReturn(List.of(bcg, penta));

    new VaccineFlyweightWarmer(vaccines, flyweights).warmUp();

    assertThat(flyweights.getPoolSize()).isEqualTo(2);
    assertThat(flyweights.getExisting("BCG")).isNotNull();
    assertThat(flyweights.getExisting("bcg")).isSameAs(flyweights.getFlyweight(bcg));
  }

  @Test
  @DisplayName("El warmer detecta codigos duplicados con atributos inconsistentes")
  void warmerRejectsInconsistentCatalog() {
    VaccineRepository vaccines = mock(VaccineRepository.class);
    VaccineFlyweightFactory flyweights = new VaccineFlyweightFactory();
    when(vaccines.findAll()).thenReturn(List.of(
        vaccine("Pentavalente", "PENTA"),
        vaccine("Pentavalente alterada", "PENTA")));

    VaccineFlyweightWarmer warmer = new VaccineFlyweightWarmer(vaccines, flyweights);

    assertThatThrownBy(warmer::warmUp)
        .isInstanceOf(InconsistentFlyweightException.class);
  }

  private VaccineEntity vaccine(String name, String code) {
    return new VaccineEntity(
        VACCINE, name, code, "PAI", (short) 1, null, null, ACTOR, Instant.now());
  }

  private VaccineOptionEntity globalOption(UUID id) {
    return new VaccineOptionEntity(
        id, VACCINE, "dose", "1", "Dosis 1", 0, true, ACTOR, Instant.now());
  }

  private ResolutionRequest request(UUID dose) {
    return new ResolutionRequest(INSTITUTION, VACCINE, dose, null, null, null, null, null);
  }
}
