package com.pai.api.catalog.controller;

import com.pai.api.catalog.dto.ReferenceCatalogResponse;
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

    private static final String READ = "@authorization.hasPermission(authentication, "
            + "'CATALOG_GLOBAL_READ') or @authorization.hasPermission(authentication, "
            + "'CATALOG_CONFIG_READ')";

    private final ReferenceCatalogService service;

    public ReferenceCatalogController(ReferenceCatalogService service) {
        this.service = service;
    }

    @GetMapping
    @PreAuthorize(READ)
    public List<ReferenceCatalogResponse> list() {
        return service.list();
    }
}
