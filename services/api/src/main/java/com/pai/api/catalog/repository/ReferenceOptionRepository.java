package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.ReferenceOptionEntity;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReferenceOptionRepository extends JpaRepository<ReferenceOptionEntity, UUID> {

  List<ReferenceOptionEntity> findByCatalogCodeAndActiveTrueOrderBySortOrderAsc(String catalogCode);

  /**
   * Opciones activas de varios catalogos en una sola consulta. Evita el N+1 al
   * listar el catalogo de referencia: el servicio agrupa por {@code catalogCode}.
   */
  List<ReferenceOptionEntity> findByCatalogCodeInAndActiveTrueOrderByCatalogCodeAscSortOrderAsc(
      Collection<String> catalogCodes);
}
