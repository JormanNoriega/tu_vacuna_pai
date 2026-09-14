package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.ReferenceCatalogResponse;
import com.pai.api.catalog.entity.ReferenceCatalogEntity;
import com.pai.api.catalog.entity.ReferenceOptionEntity;
import com.pai.api.catalog.repository.ReferenceCatalogRepository;
import com.pai.api.catalog.repository.ReferenceOptionRepository;
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Catalogo de referencia (listas cerradas del legacy: tipo de documento, sexo,
 * genero, regimen, etnia, contraindicaciones, reacciones, ...). Solo lectura.
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
    List<ReferenceCatalogResponse> result = new ArrayList<>();
    for (ReferenceCatalogEntity catalog : catalogs.findAllByOrderByCodeAsc()) {
      List<ReferenceCatalogResponse.OptionDto> optionDtos = new ArrayList<>();
      for (ReferenceOptionEntity option :
          options.findByCatalogCodeAndActiveTrueOrderBySortOrderAsc(catalog.getCode())) {
        optionDtos.add(new ReferenceCatalogResponse.OptionDto(
            option.getCode(), option.getLabel(), option.getSortOrder()));
      }
      result.add(new ReferenceCatalogResponse(catalog.getCode(), catalog.getName(), optionDtos));
    }
    return result;
  }
}
