package com.pai.api.catalog.controller;

import com.pai.api.catalog.dto.*;
import com.pai.api.catalog.service.InstitutionVaccineOptionService;
import com.pai.api.catalog.service.InstitutionVaccineService;
import com.pai.api.shared.security.ActorResolver;
import jakarta.validation.Valid;
import java.util.*;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/institutions/{institutionId}/vaccines")
public class InstitutionCatalogController {
  private final InstitutionVaccineService service;
  private final InstitutionVaccineOptionService options;

  public InstitutionCatalogController(
      InstitutionVaccineService s, InstitutionVaccineOptionService options) {
    service = s;
    this.options = options;
  }

  @GetMapping
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_CONFIG_READ')")
  public List<InstitutionVaccineResponse> list(Authentication a, @PathVariable UUID institutionId) {
    return service.list(ActorResolver.actorId(a), institutionId);
  }

  @GetMapping("/available")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_CONFIG_READ')")
  public List<VaccineResponse> available(Authentication a, @PathVariable UUID institutionId) {
    return service.available(ActorResolver.actorId(a), institutionId);
  }

  @PostMapping("/{vaccineId}/enable")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_CONFIG_WRITE')")
  public ResponseEntity<Void> enable(
      Authentication a, @PathVariable UUID institutionId, @PathVariable UUID vaccineId) {
    service.enable(ActorResolver.actorId(a), institutionId, vaccineId);
    return ResponseEntity.noContent().build();
  }

  @PostMapping("/{vaccineId}/disable")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_CONFIG_WRITE')")
  public ResponseEntity<Void> disable(
      Authentication a, @PathVariable UUID institutionId, @PathVariable UUID vaccineId) {
    service.disable(ActorResolver.actorId(a), institutionId, vaccineId);
    return ResponseEntity.noContent().build();
  }

  @PostMapping("/clone")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_CONFIG_WRITE')")
  public CloneCatalogResponse clone(
      Authentication a,
      @PathVariable UUID institutionId,
      @Valid @RequestBody CloneCatalogRequest r) {
    return service.clone(ActorResolver.actorId(a), institutionId, r.includeDefaultConfig());
  }

  @GetMapping("/{vaccineId}/options")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_CONFIG_READ')")
  public List<OptionResponse> options(
      Authentication a, @PathVariable UUID institutionId, @PathVariable UUID vaccineId) {
    return options.options(ActorResolver.actorId(a), institutionId, vaccineId);
  }

  @PostMapping("/{vaccineId}/options")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_CONFIG_WRITE')")
  public ResponseEntity<OptionResponse> createOption(
      Authentication a,
      @PathVariable UUID institutionId,
      @PathVariable UUID vaccineId,
      @Valid @RequestBody OptionRequest r) {
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(options.createOption(ActorResolver.actorId(a), institutionId, vaccineId, r));
  }

  @PutMapping("/{vaccineId}/options/{optionId}")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_CONFIG_WRITE')")
  public OptionResponse update(
      Authentication a,
      @PathVariable UUID institutionId,
      @PathVariable UUID vaccineId,
      @PathVariable UUID optionId,
      @Valid @RequestBody OptionRequest r) {
    return options.updateOption(ActorResolver.actorId(a), institutionId, vaccineId, optionId, r);
  }

  @DeleteMapping("/{vaccineId}/options/{optionId}")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_CONFIG_WRITE')")
  public ResponseEntity<Void> delete(
      Authentication a,
      @PathVariable UUID institutionId,
      @PathVariable UUID vaccineId,
      @PathVariable UUID optionId,
      @RequestParam long version) {
    options.deleteOption(ActorResolver.actorId(a), institutionId, vaccineId, optionId, version);
    return ResponseEntity.noContent().build();
  }

  @GetMapping("/{vaccineId}/suggested-options")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_CONFIG_READ')")
  public List<OptionResponse> suggested(
      Authentication a, @PathVariable UUID institutionId, @PathVariable UUID vaccineId) {
    return options.suggested(ActorResolver.actorId(a), institutionId, vaccineId);
  }

  @PostMapping("/{vaccineId}/import-suggested-options")
  @PreAuthorize("@authorization.hasPermission(authentication, 'CATALOG_CONFIG_WRITE')")
  public List<OptionResponse> importSuggested(
      Authentication a, @PathVariable UUID institutionId, @PathVariable UUID vaccineId) {
    return options.importSuggested(ActorResolver.actorId(a), institutionId, vaccineId);
  }
}
