package com.pai.api.catalog.service;

import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.exception.InconsistentFlyweightException;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.springframework.stereotype.Component;

/**
 * Fabrica Flyweight (GoF) encargada de administrar y reutilizar el pool
 * de instancias compartidas de vacunas del catalogo PAI.
 *
 * <p>Garantias de diseno:
 * <ul>
 *   <li>Reutilizacion de referencias: Si la vacuna ya fue creada, retorna la misma
 *       instancia existente sin alojar memoria adicional en el Heap.</li>
 *   <li>Integracion con {@link VaccineEntity}: Permite obtener o cachear flyweights
 *       directamente desde las entidades persistentes del catalogo.</li>
 *   <li>Validacion de consistencia: Si se solicita el mismo codigo con atributos diferentes,
 *       lanza {@link InconsistentFlyweightException}.</li>
 *   <li>Thread-Safety: Basada en {@link ConcurrentHashMap} para acceso concurrente seguro
 *       en Spring Boot.</li>
 * </ul>
 */
@Component
public class VaccineFlyweightFactory {

  private final ConcurrentMap<String, VaccineFlyweight> pool = new ConcurrentHashMap<>();

  /**
   * Obtiene la instancia compartida a partir de una entidad persistente {@link VaccineEntity}.
   * Facilita la integracion directa entre la persistencia JPA del catalogo y el pool de Flyweights.
   *
   * @param entity Entidad JPA persistente de la vacuna
   * @return Instancia unica compartida de {@link VaccineFlyweight}
   */
  public VaccineFlyweight getFlyweight(VaccineEntity entity) {
    Objects.requireNonNull(entity, "VaccineEntity no puede ser nula");
    return getFlyweight(
        entity.getCode(),
        entity.getName(),
        entity.getCategory(),
        entity.hasLot(),
        entity.hasSyringe());
  }

  /**
   * Obtiene la instancia compartida de la vacuna correspondiente al codigo especificado.
   * Si no existe en el pool, la crea de forma atomica y la almacena.
   * Si ya existe, valida que los atributos recibidos coincidan con la definicion existente.
   *
   * @param code Codigo unico de la vacuna (ej. "BCG", "PENTA")
   * @param name Nombre oficial del biologico
   * @param category Categoria clinica (ej. "BIOLOGICO_INFANTIL")
   * @param requiresLot Si la aplicacion exige numero de lote
   * @param requiresSyringe Si la aplicacion exige tipo de jeringa
   * @return Instancia unica compartida de {@link VaccineFlyweight}
   */
  public VaccineFlyweight getFlyweight(
      String code,
      String name,
      String category,
      boolean requiresLot,
      boolean requiresSyringe) {
    Objects.requireNonNull(code, "code no puede ser nulo");
    String normalizedCode = code.trim().toUpperCase();

    return pool.compute(normalizedCode, (key, existing) -> {
      if (existing == null) {
        return new SharedVaccineFlyweight(key, name, category, requiresLot, requiresSyringe);
      }
      validateConsistency(existing, name, category, requiresLot, requiresSyringe);
      return existing;
    });
  }

  /**
   * Consulta si una vacuna ya existe en el pool de memoria sin crearla.
   */
  public VaccineFlyweight getExisting(String code) {
    if (code == null) {
      return null;
    }
    return pool.get(code.trim().toUpperCase());
  }

  /**
   * Retorna el numero de instancias unicas en el pool (debe coincidir con la cantidad
   * de tipos de vacunas distintos, nunca con la cantidad de dosis aplicadas).
   */
  public int getPoolSize() {
    return pool.size();
  }

  /**
   * Limpia el pool de memoria (util en pruebas y recargas de catalogo).
   */
  public void clear() {
    pool.clear();
  }

  private void validateConsistency(
      VaccineFlyweight existing,
      String name,
      String category,
      boolean requiresLot,
      boolean requiresSyringe) {
    if (name != null && !existing.getName().equalsIgnoreCase(name.trim())) {
      throw new InconsistentFlyweightException(String.format(
          "Inconsistencia en Flyweight para codigo '%s': nombre existente '%s' vs recibido '%s'",
          existing.getCode(), existing.getName(), name));
    }
    if (category != null && !existing.getCategory().equalsIgnoreCase(category.trim())) {
      throw new InconsistentFlyweightException(String.format(
          "Inconsistencia en Flyweight para codigo '%s': categoria existente '%s' vs recibida '%s'",
          existing.getCode(), existing.getCategory(), category));
    }
    if (existing.isRequiresLot() != requiresLot) {
      throw new InconsistentFlyweightException(String.format(
          "Inconsistencia en Flyweight para codigo '%s': requiresLot existente %b vs recibido %b",
          existing.getCode(), existing.isRequiresLot(), requiresLot));
    }
    if (existing.isRequiresSyringe() != requiresSyringe) {
      throw new InconsistentFlyweightException(String.format(
          "Inconsistencia en Flyweight para codigo '%s': requiresSyringe existente %b vs recibido %b",
          existing.getCode(), existing.isRequiresSyringe(), requiresSyringe));
    }
  }
}
