package com.pai.api.catalog.controller;

import com.pai.api.catalog.dto.ReferenceCatalogResponse;
import com.pai.api.catalog.service.CatalogPermissions;
import com.pai.api.catalog.service.ReferenceCatalogService;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Catalogos de referencia (listas cerradas del legacy). Los consume el wizard
 * de nueva atencion para los campos de paciente.
 */
@RestController
@RequestMapping("/api/v1/catalogs/reference")
public class ReferenceCatalogController {

  private final ReferenceCatalogService service;

  public ReferenceCatalogController(ReferenceCatalogService service) {
    this.service = service;
  }

  @GetMapping
  @PreAuthorize(CatalogPermissions.READ)
  public List<ReferenceCatalogResponse> list() {
    return service.list();
  }
}
