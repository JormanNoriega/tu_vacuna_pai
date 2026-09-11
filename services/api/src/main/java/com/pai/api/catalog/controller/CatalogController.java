package com.pai.api.catalog.controller;

import com.pai.api.catalog.dto.*;
import com.pai.api.catalog.service.*;
import com.pai.api.identity.service.AuthorizedUser;
import jakarta.validation.Valid;
import java.util.*;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/catalogs")
public class CatalogController {
    private final VaccineService service;
    private final EffectiveCatalogService effective;

    public CatalogController(VaccineService s, EffectiveCatalogService e) {
        service = s;
        effective = e;
    }

    private UUID actor(Authentication a) {
        return ((AuthorizedUser) a.getPrincipal()).getId();
    }

    @GetMapping("/effective")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_READ') or"
            + " @authorization.hasPermission(authentication, 'CATALOG_CONFIG_READ')")
    public EffectiveCatalogResponse effective(Authentication a) {
        return effective.list(actor(a));
    }

    @GetMapping("/vaccines")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_READ')")
    public List<VaccineResponse> list(Authentication a) {
        return service.list(actor(a));
    }

    @PostMapping("/vaccines")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
    public ResponseEntity<VaccineResponse> create(Authentication a, @Valid @RequestBody VaccineRequest r) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(actor(a), r));
    }

    @PutMapping("/vaccines/{id}")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
    public VaccineResponse update(
            Authentication a, @PathVariable UUID id, @RequestParam long version, @Valid @RequestBody VaccineRequest r) {
        return service.update(actor(a), id, r, version);
    }

    @DeleteMapping("/vaccines/{id}")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
    public ResponseEntity<Void> delete(Authentication a, @PathVariable UUID id, @RequestParam long version) {
        service.delete(actor(a), id, version);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/vaccines/{id}/options")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_READ')")
    public List<OptionResponse> options(Authentication a, @PathVariable UUID id) {
        return service.globalOptions(actor(a), id);
    }

    @PostMapping("/vaccines/{id}/options")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
    public ResponseEntity<OptionResponse> option(
            Authentication a, @PathVariable UUID id, @Valid @RequestBody OptionRequest r) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.createOption(actor(a), id, r));
    }

    @PutMapping("/vaccines/{vaccineId}/options/{id}")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
    public OptionResponse optionUpdate(
            Authentication a,
            @PathVariable UUID vaccineId,
            @PathVariable UUID id,
            @Valid @RequestBody OptionRequest r) {
        return service.updateOption(actor(a), vaccineId, id, r);
    }

    @DeleteMapping("/vaccines/{vaccineId}/options/{id}")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
    public ResponseEntity<Void> optionDelete(
            Authentication a, @PathVariable UUID vaccineId, @PathVariable UUID id, @RequestParam long version) {
        service.deleteOption(actor(a), vaccineId, id, version);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/vaccines/{id}/templates")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_READ')")
    public List<OptionResponse> templates(Authentication a, @PathVariable UUID id) {
        return service.templates(actor(a), id);
    }

    @PostMapping("/vaccines/{id}/templates")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
    public ResponseEntity<OptionResponse> template(
            Authentication a, @PathVariable UUID id, @Valid @RequestBody OptionRequest r) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.createTemplate(actor(a), id, r));
    }

    @PutMapping("/vaccines/{vaccineId}/templates/{id}")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
    public OptionResponse updateTemplate(
            Authentication a,
            @PathVariable UUID vaccineId,
            @PathVariable UUID id,
            @Valid @RequestBody OptionRequest r) {
        return service.updateTemplate(actor(a), vaccineId, id, r);
    }

    @PatchMapping("/vaccines/{vaccineId}/templates/{id}")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
    public OptionResponse patchTemplate(
            Authentication a,
            @PathVariable UUID vaccineId,
            @PathVariable UUID id,
            @Valid @RequestBody OptionRequest r) {
        return service.updateTemplate(actor(a), vaccineId, id, r);
    }

    @DeleteMapping("/vaccines/{vaccineId}/templates/{id}")
    @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
    public ResponseEntity<Void> deleteTemplate(
            Authentication a, @PathVariable UUID vaccineId, @PathVariable UUID id, @RequestParam long version) {
        service.deleteTemplate(actor(a), vaccineId, id, version);
        return ResponseEntity.noContent().build();
    }
}
