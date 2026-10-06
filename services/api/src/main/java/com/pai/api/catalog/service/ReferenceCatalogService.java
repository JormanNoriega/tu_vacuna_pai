package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.ReferenceCatalogResponse;
import com.pai.api.catalog.entity.ReferenceCatalogEntity;
import com.pai.api.catalog.entity.ReferenceOptionEntity;
import com.pai.api.catalog.repository.ReferenceCatalogRepository;
import com.pai.api.catalog.repository.ReferenceOptionRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Catalogo de referencia (listas cerradas del legacy: tipo de documento, sexo,
 * genero, regimen, etnia, contraindicaciones, reacciones, ...). Solo lectura.
 * Las opciones se cargan en bloque y se agrupan en memoria (evita el N+1).
 */
@Service
public class ReferenceCatalogService {

  private final ReferenceCatalogRepository catalogs;
  private final ReferenceOptionRepository options;

  public ReferenceCatalogService(
      ReferenceCatalogRepository catalogs, ReferenceOptionRepository options) {
    this.catalogs = catalogs;
    this.options = options;
  }

  @Transactional(readOnly = true)
  public List<ReferenceCatalogResponse> list() {
    List<ReferenceCatalogEntity> catalogList = catalogs.findAllByOrderByCodeAsc();
    if (catalogList.isEmpty()) {
      return List.of();
    }

    Map<String, List<ReferenceOptionEntity>> optionsByCatalog = options
        .findByCatalogCodeInAndActiveTrueOrderByCatalogCodeAscSortOrderAsc(
            catalogList.stream().map(ReferenceCatalogEntity::getCode).toList())
        .stream()
        .collect(Collectors.groupingBy(ReferenceOptionEntity::getCatalogCode));

    List<ReferenceCatalogResponse> result = new ArrayList<>(catalogList.size());
    for (ReferenceCatalogEntity catalog : catalogList) {
      List<ReferenceCatalogResponse.OptionDto> optionDtos =
          optionsByCatalog.getOrDefault(catalog.getCode(), List.of()).stream()
              .map(option -> new ReferenceCatalogResponse.OptionDto(
                  option.getCode(), option.getLabel(), option.getSortOrder()))
              .toList();
      result.add(new ReferenceCatalogResponse(catalog.getCode(), catalog.getName(), optionDtos));
    }
    return result;
  }
}
