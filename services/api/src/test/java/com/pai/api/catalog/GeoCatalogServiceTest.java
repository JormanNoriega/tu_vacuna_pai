package com.pai.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.catalog.dto.GeoDepartmentResponse;
import com.pai.api.catalog.dto.GeoFullDepartmentResponse;
import com.pai.api.catalog.dto.GeoMunicipalityResponse;
import com.pai.api.catalog.entity.GeoCountryEntity;
import com.pai.api.catalog.entity.GeoDepartmentEntity;
import com.pai.api.catalog.entity.GeoMunicipalityEntity;
import com.pai.api.catalog.repository.GeoCountryRepository;
import com.pai.api.catalog.repository.GeoDepartmentRepository;
import com.pai.api.catalog.repository.GeoMunicipalityRepository;
import com.pai.api.catalog.service.GeoCatalogService;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class GeoCatalogServiceTest {

  private GeoCountryRepository countries;
  private GeoDepartmentRepository departments;
  private GeoMunicipalityRepository municipalities;
  private GeoCatalogService service;

  @BeforeEach
  void setUp() {
    countries = mock(GeoCountryRepository.class);
    departments = mock(GeoDepartmentRepository.class);
    municipalities = mock(GeoMunicipalityRepository.class);
    service = new GeoCatalogService(countries, departments, municipalities);
  }

  @Test
  void countries_mapsEntitiesOrderedByName() {
    UUID id = UUID.randomUUID();
    when(countries.findAllByOrderByNameAsc())
        .thenReturn(List.of(new GeoCountryEntity(id, "170", "Colombia")));

    List<GeoDepartmentResponse> result = service.countries();

    assertThat(result).hasSize(1);
    assertThat(result.get(0).code()).isEqualTo("170");
    assertThat(result.get(0).name()).isEqualTo("Colombia");
    assertThat(result.get(0).id()).isEqualTo(id);
  }

  @Test
  void departments_mapsEntitiesOrderedByName() {
    UUID id = UUID.randomUUID();
    when(departments.findAllByOrderByNameAsc())
        .thenReturn(List.of(new GeoDepartmentEntity(id, UUID.randomUUID(), "05", "Antioquia")));

    List<GeoDepartmentResponse> result = service.departments();

    assertThat(result).hasSize(1);
    assertThat(result.get(0).code()).isEqualTo("05");
    assertThat(result.get(0).name()).isEqualTo("Antioquia");
    assertThat(result.get(0).id()).isEqualTo(id);
  }

  @Test
  void municipalities_mapsEntitiesForDepartment() {
    UUID departmentId = UUID.randomUUID();
    UUID municipalityId = UUID.randomUUID();
    when(municipalities.findByDepartmentIdOrderByNameAsc(departmentId))
        .thenReturn(
            List.of(new GeoMunicipalityEntity(municipalityId, departmentId, "05001", "Medellin")));

    List<GeoMunicipalityResponse> result = service.municipalities(departmentId);

    assertThat(result).hasSize(1);
    assertThat(result.get(0).code()).isEqualTo("05001");
    assertThat(result.get(0).departmentId()).isEqualTo(departmentId);
  }

  @Test
  void municipalities_rejectsMissingDepartment() {
    assertThatThrownBy(() -> service.municipalities(null))
        .isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  void full_groupsMunicipalitiesUnderTheirDepartment() {
    UUID departmentId = UUID.randomUUID();
    UUID otherDepartmentId = UUID.randomUUID();
    when(departments.findAllByOrderByNameAsc())
        .thenReturn(List.of(
            new GeoDepartmentEntity(departmentId, UUID.randomUUID(), "05", "Antioquia"),
            new GeoDepartmentEntity(otherDepartmentId, UUID.randomUUID(), "08", "Atlantico")));
    when(municipalities.findAllByOrderByNameAsc())
        .thenReturn(List.of(
            new GeoMunicipalityEntity(UUID.randomUUID(), departmentId, "05001", "Medellin"),
            new GeoMunicipalityEntity(
                UUID.randomUUID(), otherDepartmentId, "08001", "Barranquilla")));

    List<GeoFullDepartmentResponse> result = service.full();

    assertThat(result).hasSize(2);
    assertThat(result.get(0).name()).isEqualTo("Antioquia");
    assertThat(result.get(0).municipalities())
        .singleElement()
        .extracting(GeoMunicipalityResponse::name)
        .isEqualTo("Medellin");
    assertThat(result.get(1).municipalities())
        .singleElement()
        .extracting(GeoMunicipalityResponse::name)
        .isEqualTo("Barranquilla");
  }

  @Test
  void full_returnsDepartmentWithoutMunicipalities() {
    UUID departmentId = UUID.randomUUID();
    when(departments.findAllByOrderByNameAsc())
        .thenReturn(
            List.of(new GeoDepartmentEntity(departmentId, UUID.randomUUID(), "05", "Antioquia")));
    when(municipalities.findAllByOrderByNameAsc()).thenReturn(List.of());

    List<GeoFullDepartmentResponse> result = service.full();

    assertThat(result)
        .singleElement()
        .extracting(GeoFullDepartmentResponse::municipalities)
        .isEqualTo(List.of());
  }
}
