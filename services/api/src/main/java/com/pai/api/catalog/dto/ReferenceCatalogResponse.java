package com.pai.api.catalog.dto;

import java.util.List;

/** Catalogo de referencia con sus opciones ordenadas. */
public record ReferenceCatalogResponse(String code, String name, List<OptionDto> options) {

  public record OptionDto(String code, String label, int sortOrder) {}
}
