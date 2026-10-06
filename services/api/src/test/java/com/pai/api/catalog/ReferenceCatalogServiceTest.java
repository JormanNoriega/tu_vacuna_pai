package com.pai.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.catalog.dto.ReferenceCatalogResponse;
import com.pai.api.catalog.entity.ReferenceCatalogEntity;
import com.pai.api.catalog.entity.ReferenceOptionEntity;
import com.pai.api.catalog.repository.ReferenceCatalogRepository;
import com.pai.api.catalog.repository.ReferenceOptionRepository;
import com.pai.api.catalog.service.ReferenceCatalogService;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class ReferenceCatalogServiceTest {

  private ReferenceCatalogRepository catalogs;
  private ReferenceOptionRepository options;
  private ReferenceCatalogService service;

  @BeforeEach
  void setUp() {
    catalogs = mock(ReferenceCatalogRepository.class);
    options = mock(ReferenceOptionRepository.class);
    service = new ReferenceCatalogService(catalogs, options);
  }

  @Test
  void list_groupsOptionsUnderTheirCatalogCode() {
    ReferenceCatalogEntity ethnicity = referenceCatalog("ethnicity", "Etnia");
    ReferenceCatalogEntity gender = referenceCatalog("gender", "Genero");
    when(catalogs.findAllByOrderByCodeAsc()).thenReturn(List.of(ethnicity, gender));
    List<ReferenceOptionEntity> allOptions = List.of(
        referenceOption("ethnicity", "mestizo", "Mestizo", 1),
        referenceOption("ethnicity", "afro", "Afro", 2),
        referenceOption("gender", "M", "Masculino", 1));
    when(options.findByCatalogCodeInAndActiveTrueOrderByCatalogCodeAscSortOrderAsc(any()))
        .thenReturn(allOptions);

    List<ReferenceCatalogResponse> result = service.list();

    assertThat(result).hasSize(2);
    ReferenceCatalogResponse ethnicityResponse = result.get(0);
    assertThat(ethnicityResponse.code()).isEqualTo("ethnicity");
    assertThat(ethnicityResponse.name()).isEqualTo("Etnia");
    assertThat(ethnicityResponse.options())
        .extracting(ReferenceCatalogResponse.OptionDto::code)
        .containsExactly("mestizo", "afro");
    assertThat(ethnicityResponse.options().get(0).label()).isEqualTo("Mestizo");
    assertThat(result.get(1).options()).hasSize(1);
  }

  @Test
  void list_returnsEmptyOptionsForCatalogWithoutRows() {
    ReferenceCatalogEntity documentType = referenceCatalog("documentType", "Tipo de documento");
    when(catalogs.findAllByOrderByCodeAsc()).thenReturn(List.of(documentType));
    when(options.findByCatalogCodeInAndActiveTrueOrderByCatalogCodeAscSortOrderAsc(any()))
        .thenReturn(List.of());

    List<ReferenceCatalogResponse> result = service.list();

    assertThat(result).hasSize(1);
    assertThat(result.get(0).options()).isEmpty();
  }

  private ReferenceCatalogEntity referenceCatalog(String code, String name) {
    ReferenceCatalogEntity entity = mock(ReferenceCatalogEntity.class);
    when(entity.getCode()).thenReturn(code);
    when(entity.getName()).thenReturn(name);
    return entity;
  }

  private ReferenceOptionEntity referenceOption(
      String catalogCode, String code, String label, int sortOrder) {
    ReferenceOptionEntity entity = mock(ReferenceOptionEntity.class);
    when(entity.getCatalogCode()).thenReturn(catalogCode);
    when(entity.getCode()).thenReturn(code);
    when(entity.getLabel()).thenReturn(label);
    when(entity.getSortOrder()).thenReturn(sortOrder);
    return entity;
  }
}
