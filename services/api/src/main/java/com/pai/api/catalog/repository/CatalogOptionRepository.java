package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.CatalogOption;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Operaciones comunes de persistencia de las opciones del catalogo global.
 * La implementan los repositorios Spring Data concretos (opciones y templates),
 * de modo que {@code VaccineService} puede compartir el algoritmo de CRUD.
 */
public interface CatalogOptionRepository<E extends CatalogOption> {

  Optional<E> findByIdAndVaccineId(UUID id, UUID vaccineId);

  List<E> lockActive(UUID vaccineId);
}
