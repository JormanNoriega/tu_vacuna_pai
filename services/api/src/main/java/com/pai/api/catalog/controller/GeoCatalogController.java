package com.pai.api.catalog.controller;

import com.pai.api.catalog.dto.GeoDepartmentResponse;
import com.pai.api.catalog.dto.GeoMunicipalityResponse;
import com.pai.api.catalog.service.GeoCatalogService;
import java.util.List;
import java.util.UUID;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Catalogo geografico (DIVIPOLA): departamentos y municipios. Lo consume el
 * formulario de paciente para las direcciones.
 */
@RestController
@RequestMapping("/api/v1/catalogs/geo")
public class GeoCatalogController {

    private static final String READ = "@authorization.hasPermission(authentication, "
            + "'CATALOG_GLOBAL_READ') or @authorization.hasPermission(authentication, "
            + "'CATALOG_CONFIG_READ')";

    private final GeoCatalogService service;

    public GeoCatalogController(GeoCatalogService service) {
        this.service = service;
    }

    @GetMapping("/departments")
    @PreAuthorize(READ)
    public List<GeoDepartmentResponse> departments() {
        return service.departments();
    }

    @GetMapping("/municipalities")
    @PreAuthorize(READ)
    public List<GeoMunicipalityResponse> municipalities(@RequestParam UUID departmentId) {
        return service.municipalities(departmentId);
    }
}
