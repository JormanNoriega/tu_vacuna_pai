package com.pai.api.catalog.controller;

import com.pai.api.catalog.dto.GeoDepartmentResponse;
import com.pai.api.catalog.dto.GeoFullDepartmentResponse;
import com.pai.api.catalog.dto.GeoMunicipalityResponse;
import com.pai.api.catalog.service.CatalogPermissions;
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

  private final GeoCatalogService service;

  public GeoCatalogController(GeoCatalogService service) {
    this.service = service;
  }

  @GetMapping("/countries")
  @PreAuthorize(CatalogPermissions.READ)
  public List<GeoDepartmentResponse> countries() {
    return service.countries();
  }

  @GetMapping("/departments")
  @PreAuthorize(CatalogPermissions.READ)
  public List<GeoDepartmentResponse> departments() {
    return service.departments();
  }

  @GetMapping("/municipalities")
  @PreAuthorize(CatalogPermissions.READ)
  public List<GeoMunicipalityResponse> municipalities(@RequestParam UUID departmentId) {
    return service.municipalities(departmentId);
  }

  /** Catalogo completo (departamentos con municipios) para la precarga offline. */
  @GetMapping("/full")
  @PreAuthorize(CatalogPermissions.READ)
  public List<GeoFullDepartmentResponse> full() {
    return service.full();
  }
}
