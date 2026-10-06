package com.pai.api.catalog.controller;

import com.pai.api.catalog.dto.*;
import com.pai.api.catalog.service.*;
import com.pai.api.shared.security.ActorResolver;
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
  private final HealthInsurerService insurers;

  public CatalogController(
      VaccineService s, EffectiveCatalogService e, HealthInsurerService insurers) {
    service = s;
    effective = e;
    this.insurers = insurers;
  }

  @GetMapping("/insurers")
  @PreAuthorize(CatalogPermissions.READ)
  public List<HealthInsurerResponse> insurers(@RequestParam(required = false) String regime) {
    return insurers.list(regime);
  }

  @GetMapping("/effective")
  @PreAuthorize(CatalogPermissions.READ)
  public EffectiveCatalogResponse effective(Authentication a) {
    return effective.list(ActorResolver.actorId(a));
  }

  @GetMapping("/vaccines")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_READ')")
  public List<VaccineResponse> list(Authentication a) {
    return service.list(ActorResolver.actorId(a));
  }

  @PostMapping("/vaccines")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
  public ResponseEntity<VaccineResponse> create(
      Authentication a, @Valid @RequestBody VaccineRequest r) {
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(service.create(ActorResolver.actorId(a), r));
  }

  @PutMapping("/vaccines/{id}")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
  public VaccineResponse update(
      Authentication a,
      @PathVariable UUID id,
      @RequestParam long version,
      @Valid @RequestBody VaccineRequest r) {
    return service.update(ActorResolver.actorId(a), id, r, version);
  }

  @DeleteMapping("/vaccines/{id}")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
  public ResponseEntity<Void> delete(
      Authentication a, @PathVariable UUID id, @RequestParam long version) {
    service.delete(ActorResolver.actorId(a), id, version);
    return ResponseEntity.noContent().build();
  }

  @GetMapping("/vaccines/{id}/options")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_READ')")
  public List<OptionResponse> options(Authentication a, @PathVariable UUID id) {
    return service.globalOptions(ActorResolver.actorId(a), id);
  }

  @PostMapping("/vaccines/{id}/options")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
  public ResponseEntity<OptionResponse> option(
      Authentication a, @PathVariable UUID id, @Valid @RequestBody OptionRequest r) {
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(service.createOption(ActorResolver.actorId(a), id, r));
  }

  @PutMapping("/vaccines/{vaccineId}/options/{id}")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
  public OptionResponse optionUpdate(
      Authentication a,
      @PathVariable UUID vaccineId,
      @PathVariable UUID id,
      @Valid @RequestBody OptionRequest r) {
    return service.updateOption(ActorResolver.actorId(a), vaccineId, id, r);
  }

  @DeleteMapping("/vaccines/{vaccineId}/options/{id}")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
  public ResponseEntity<Void> optionDelete(
      Authentication a,
      @PathVariable UUID vaccineId,
      @PathVariable UUID id,
      @RequestParam long version) {
    service.deleteOption(ActorResolver.actorId(a), vaccineId, id, version);
    return ResponseEntity.noContent().build();
  }

  @GetMapping("/vaccines/{id}/templates")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_READ')")
  public List<OptionResponse> templates(Authentication a, @PathVariable UUID id) {
    return service.templates(ActorResolver.actorId(a), id);
  }

  @PostMapping("/vaccines/{id}/templates")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
  public ResponseEntity<OptionResponse> template(
      Authentication a, @PathVariable UUID id, @Valid @RequestBody OptionRequest r) {
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(service.createTemplate(ActorResolver.actorId(a), id, r));
  }

  @PutMapping("/vaccines/{vaccineId}/templates/{id}")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
  public OptionResponse updateTemplate(
      Authentication a,
      @PathVariable UUID vaccineId,
      @PathVariable UUID id,
      @Valid @RequestBody OptionRequest r) {
    return service.updateTemplate(ActorResolver.actorId(a), vaccineId, id, r);
  }

  @DeleteMapping("/vaccines/{vaccineId}/templates/{id}")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_GLOBAL_WRITE')")
  public ResponseEntity<Void> deleteTemplate(
      Authentication a,
      @PathVariable UUID vaccineId,
      @PathVariable UUID id,
      @RequestParam long version) {
    service.deleteTemplate(ActorResolver.actorId(a), vaccineId, id, version);
    return ResponseEntity.noContent().build();
  }
}
