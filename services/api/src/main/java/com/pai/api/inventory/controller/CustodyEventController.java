package com.pai.api.inventory.controller;

import com.pai.api.inventory.service.CustodyEventService;
import com.pai.api.shared.exceptions.ErrorResponse;
import com.pai.api.shared.security.ActorResolver;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.util.List;
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
@ConditionalOnProperty(name = "app.inventory.api-enabled", havingValue = "true")
public class CustodyEventController {
  private final CustodyEventService service;
  public CustodyEventController(CustodyEventService service) { this.service = service; }
  public record ReportRequest(@NotNull UUID id, @NotNull UUID assignmentId, @Positive int vials,
      @NotBlank String kind, @NotBlank @Size(max = 1000) String note) {}
  public record ConfirmRequest(@NotBlank String disposition, @NotBlank @Size(max = 1000) String note) {}

  @PostMapping("/custody-events")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public ResponseEntity<InventoryController.CreatedId> report(Authentication auth, @PathVariable UUID institutionId,
      @Valid @RequestBody ReportRequest request) {
    service.report(ActorResolver.actorId(auth), institutionId, request.id(), request.assignmentId(),
        request.vials(), request.kind(), request.note());
    return ResponseEntity.status(HttpStatus.CREATED).body(new InventoryController.CreatedId(request.id()));
  }

  @GetMapping("/custody-events")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public List<CustodyEventService.Event> list(Authentication auth, @PathVariable UUID institutionId) {
    return service.list(ActorResolver.actorId(auth), institutionId, false);
  }

  @GetMapping("/my-custody-events")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public List<CustodyEventService.Event> mine(Authentication auth, @PathVariable UUID institutionId) {
    return service.list(ActorResolver.actorId(auth), institutionId, true);
  }

  @PostMapping("/custody-events/{eventId}/confirm")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public ResponseEntity<Void> confirm(Authentication auth, @PathVariable UUID institutionId, @PathVariable UUID eventId,
      @Valid @RequestBody ConfirmRequest request) {
    service.confirmReturn(ActorResolver.actorId(auth), institutionId, eventId, request.disposition(), request.note());
    return ResponseEntity.noContent().build();
  }

  @ExceptionHandler(DataIntegrityViolationException.class)
  public ResponseEntity<ErrorResponse> conflict(DataIntegrityViolationException ignored) {
    return ResponseEntity.status(HttpStatus.CONFLICT).body(new ErrorResponse("CUSTODY_CONFLICT",
        "La operación ya existe o entra en conflicto; consulta el registro antes de repetirla."));
  }
}
