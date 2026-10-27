package com.pai.api.catalog.service;

import com.pai.api.catalog.repository.VaccineRepository;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Precarga el pool de {@link VaccineFlyweightFactory} al iniciar la aplicacion.
 *
 * <p>Sin esta precarga el pool arrancaria vacio: la fabrica solo crearia
 * instancias cuando alguien la invocara, dejando el patron Flyweight (PE-04)
 * sin efecto en el arranque. Al cargar el catalogo una sola vez, cada vacuna
 * queda representada por exactamente una instancia inmutable en memoria, lista
 * para ser compartida por el registro de dosis y los reportes.
 */
@Component
public class VaccineFlyweightWarmer {

  private final VaccineRepository vaccines;
  private final VaccineFlyweightFactory flyweights;

  public VaccineFlyweightWarmer(VaccineRepository vaccines, VaccineFlyweightFactory flyweights) {
    this.vaccines = vaccines;
    this.flyweights = flyweights;
  }

  /**
   * Carga todas las vacunas del catalogo en el pool. Si dos filas comparten
   * codigo con atributos distintos, {@code VaccineFlyweightFactory} lanza
   * {@code InconsistentFlyweightException} y la aplicacion no arranca: es una
   * inconsistencia real del catalogo, no un fallo tolerable.
   */
  @EventListener(ApplicationReadyEvent.class)
  @Transactional(readOnly = true)
  public void warmUp() {
    vaccines.findAll().forEach(flyweights::getFlyweight);
  }
}
