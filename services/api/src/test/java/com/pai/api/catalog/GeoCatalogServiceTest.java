package com.pai.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.pai.api.catalog.dto.GeoDepartmentResponse;
import com.pai.api.catalog.dto.GeoMunicipalityResponse;
import com.pai.api.catalog.entity.GeoDepartmentEntity;
import com.pai.api.catalog.entity.GeoMunicipalityEntity;
import com.pai.api.catalog.repository.GeoDepartmentRepository;
import com.pai.api.catalog.repository.GeoMunicipalityRepository;
import com.pai.api.catalog.service.GeoCatalogService;

class GeoCatalogServiceTest {

    private GeoDepartmentRepository departments;
    private GeoMunicipalityRepository municipalities;
    private GeoCatalogService service;

    @BeforeEach
    void setUp() {
        departments = mock(GeoDepartmentRepository.class);
        municipalities = mock(GeoMunicipalityRepository.class);
        service = new GeoCatalogService(departments, municipalities);
    }

    @Test
    void departments_mapsEntitiesOrderedByName() {
        UUID id = UUID.randomUUID();
        when(departments.findAllByOrderByNameAsc())
            .thenReturn(List.of(new GeoDepartmentEntity(id, UUID.randomUUID(),
                "05", "Antioquia")));

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
            .thenReturn(List.of(new GeoMunicipalityEntity(municipalityId, departmentId,
                "05001", "Medellin")));

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
}
