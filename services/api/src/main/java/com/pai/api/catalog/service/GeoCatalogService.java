package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.GeoDepartmentResponse;
import com.pai.api.catalog.dto.GeoMunicipalityResponse;
import com.pai.api.catalog.repository.GeoDepartmentRepository;
import com.pai.api.catalog.repository.GeoMunicipalityRepository;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Consulta del catalogo geografico (DIVIPOLA). */
@Service
public class GeoCatalogService {

    private final GeoDepartmentRepository departments;
    private final GeoMunicipalityRepository municipalities;

    public GeoCatalogService(GeoDepartmentRepository departments, GeoMunicipalityRepository municipalities) {
        this.departments = departments;
        this.municipalities = municipalities;
    }

    @Transactional(readOnly = true)
    public List<GeoDepartmentResponse> departments() {
        return departments.findAllByOrderByNameAsc().stream()
                .map(department ->
                        new GeoDepartmentResponse(department.getId(), department.getCode(), department.getName()))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<GeoMunicipalityResponse> municipalities(UUID departmentId) {
        if (departmentId == null) {
            throw new IllegalArgumentException("El departamento es obligatorio.");
        }
        return municipalities.findByDepartmentIdOrderByNameAsc(departmentId).stream()
                .map(municipality -> new GeoMunicipalityResponse(
                        municipality.getId(),
                        municipality.getCode(),
                        municipality.getName(),
                        municipality.getDepartmentId()))
                .toList();
    }
}
