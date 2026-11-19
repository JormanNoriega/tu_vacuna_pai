package com.pai.api.inventory.controller;

import com.pai.api.inventory.service.CustodyWorkflowService;
import com.pai.api.shared.exceptions.ErrorResponse;
import com.pai.api.shared.security.ActorResolver;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.util.UUID;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/institutions/{institutionId}/inventory")
@ConditionalOnProperty(name="app.inventory.api-enabled",havingValue="true")
public class CustodyWorkflowController {
  private final CustodyWorkflowService service;
  public CustodyWorkflowController(CustodyWorkflowService service) { this.service=service; }
  public record CountRequest(@NotNull UUID id, @NotNull @PositiveOrZero Integer closedVials,
      @NotNull @PositiveOrZero Integer openVials, @NotNull @PositiveOrZero Integer exhaustedVials,
      @NotNull @PositiveOrZero Integer discardedVials, @NotNull @PositiveOrZero Integer discardedDoses,
      @NotBlank @Size(max=1000) String note) {}
  public record EvidenceRequest(@NotNull UUID id, @NotBlank @Size(max=1000) String note) {}
  public record LinkRequest(@NotNull UUID id, @NotNull UUID doseId, @NotBlank @Size(max=1000) String note) {}
  public record ReviewRequest(@NotNull UUID id, @NotNull UUID countId,
      @NotBlank @Size(max=500) String basis, @NotBlank @Size(max=1000) String note) {}

  @GetMapping("/assignments/{assignmentId}/custody-workflow")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public CustodyWorkflowService.Workflow read(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID assignmentId) {
    return service.read(ActorResolver.actorId(auth),institutionId,assignmentId,false);
  }
  @GetMapping("/my-assignments/{assignmentId}/custody-workflow")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public CustodyWorkflowService.Workflow mine(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID assignmentId) {
    return service.read(ActorResolver.actorId(auth),institutionId,assignmentId,true);
  }
  @PostMapping("/my-assignments/{assignmentId}/custody-counts")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public InventoryController.CreatedId count(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID assignmentId, @Valid @RequestBody CountRequest r) {
    return new InventoryController.CreatedId(service.recordCount(ActorResolver.actorId(auth),institutionId,assignmentId,
        new CustodyWorkflowService.Count(r.id(),r.closedVials(),r.openVials(),r.exhaustedVials(),
            r.discardedVials(),r.discardedDoses(),r.note(),null,null)));
  }
  @PostMapping("/my-assignments/{assignmentId}/clinical-links")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public InventoryController.CreatedId linkMine(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID assignmentId, @Valid @RequestBody LinkRequest r) {
    return new InventoryController.CreatedId(service.linkDose(ActorResolver.actorId(auth),institutionId,assignmentId,
        r.id(),r.doseId(),r.note(),true));
  }
  @PostMapping("/assignments/{assignmentId}/clinical-links")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE') and @authorization.hasPermission(authentication, 'ATTENTION_READ')")
  public InventoryController.CreatedId link(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID assignmentId, @Valid @RequestBody LinkRequest r) {
    return new InventoryController.CreatedId(service.linkDose(ActorResolver.actorId(auth),institutionId,assignmentId,
        r.id(),r.doseId(),r.note(),false));
  }
  @PostMapping("/assignments/{assignmentId}/transfer-finalizations")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public InventoryController.CreatedId finalizeTransfer(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID assignmentId, @Valid @RequestBody EvidenceRequest r) {
    return new InventoryController.CreatedId(service.finalizeTransfer(ActorResolver.actorId(auth),institutionId,
        assignmentId,r.id(),r.note()));
  }
  @PostMapping("/assignments/{assignmentId}/custody-reviews")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public InventoryController.CreatedId review(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID assignmentId, @Valid @RequestBody ReviewRequest r) {
    return new InventoryController.CreatedId(service.review(ActorResolver.actorId(auth),institutionId,assignmentId,
        r.id(),r.countId(),r.basis(),r.note()));
  }
  @ExceptionHandler(DataIntegrityViolationException.class)
  public ResponseEntity<ErrorResponse> conflict(DataIntegrityViolationException ignored) {
    return ResponseEntity.status(HttpStatus.CONFLICT).body(new ErrorResponse("CUSTODY_CONFLICT",
        "Identificador o vínculo en conflicto. Actualiza antes de registrar otra operación."));
  }
}
