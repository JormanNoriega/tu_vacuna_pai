package com.pai.api.inventory.controller;

import com.pai.api.inventory.domain.VialTransfer;
import com.pai.api.inventory.service.InventoryService;
import com.pai.api.shared.exceptions.ErrorResponse;
import com.pai.api.shared.security.ActorResolver;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** API inicial online, deshabilitada hasta validar migracion y operacion en PostgreSQL. */
@RestController
@RequestMapping("/api/v1/institutions/{institutionId}/inventory")
@ConditionalOnProperty(name = "app.inventory.api-enabled", havingValue = "true")
public class InventoryController {
  private final InventoryService service;

  public InventoryController(InventoryService service) {
    this.service = service;
  }

  public record CreateLotRequest(@NotNull UUID id, @NotNull UUID vaccineId,
      @NotBlank @Size(max = 200) String manufacturer, @NotBlank @Size(max = 200) String lotNumber,
      @NotNull LocalDate expiresOn, @Positive int dosesPerVial) {}

  public record EntryRequest(@NotNull UUID movementId, @NotNull UUID lotId, @Positive int vials,
      @NotNull Instant occurredAt, @NotBlank @Size(max = 1000) String note) {}

  public record CreateLotWithEntryRequest(@NotNull UUID id, @NotNull UUID vaccineId,
      @NotBlank @Size(max = 200) String manufacturer, @NotBlank @Size(max = 200) String lotNumber,
      @NotNull LocalDate expiresOn, @Positive int dosesPerVial, @NotNull UUID movementId,
      @Positive int vials, @NotNull Instant occurredAt, @NotBlank @Size(max = 1000) String note) {}

  public record DispatchRequest(@NotNull UUID movementId, @NotNull UUID assignmentId,
      @NotNull UUID lotId, @NotNull UUID vaccinatorId, @Positive int vials,
      @NotNull Instant occurredAt, @NotBlank @Size(max = 1000) String note, UUID campaignId) {}

  public record ReceiveRequest(@Positive int vials) {}

  public record CreatedId(UUID id) {}

  @GetMapping("/lots")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public List<InventoryService.Lot> lots(Authentication auth, @PathVariable UUID institutionId) {
    return service.listLots(ActorResolver.actorId(auth), institutionId);
  }

  @PostMapping("/lots")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public ResponseEntity<CreatedId> createLot(Authentication auth, @PathVariable UUID institutionId,
      @Valid @RequestBody CreateLotRequest request) {
    UUID id = service.createLot(ActorResolver.actorId(auth), institutionId, request.id(),
        request.vaccineId(), request.manufacturer(), request.lotNumber(), request.expiresOn(),
        request.dosesPerVial());
    return ResponseEntity.status(HttpStatus.CREATED).body(new CreatedId(id));
  }

  @PostMapping("/lots-with-entry")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public ResponseEntity<CreatedId> createLotWithEntry(Authentication auth, @PathVariable UUID institutionId,
      @Valid @RequestBody CreateLotWithEntryRequest request) {
    UUID id = service.createLotWithEntry(ActorResolver.actorId(auth), institutionId, request.id(),
        request.vaccineId(), request.manufacturer(), request.lotNumber(), request.expiresOn(),
        request.dosesPerVial(), request.movementId(), request.vials(), request.occurredAt(), request.note());
    return ResponseEntity.status(HttpStatus.CREATED).body(new CreatedId(id));
  }

  @GetMapping("/movements")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public List<InventoryService.MovementView> movements(Authentication auth, @PathVariable UUID institutionId) {
    return service.listMovements(ActorResolver.actorId(auth), institutionId);
  }

  @PostMapping("/entries")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public ResponseEntity<CreatedId> entry(Authentication auth, @PathVariable UUID institutionId,
      @Valid @RequestBody EntryRequest request) {
    service.recordEntry(ActorResolver.actorId(auth), institutionId, request.movementId(),
        request.lotId(), request.vials(), request.occurredAt(), request.note());
    return ResponseEntity.status(HttpStatus.CREATED).body(new CreatedId(request.movementId()));
  }

  @GetMapping("/assignments")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public List<InventoryService.AssignmentView> assignments(Authentication auth,
      @PathVariable UUID institutionId) {
    return service.listAssignments(ActorResolver.actorId(auth), institutionId);
  }

  @GetMapping("/my-assignments")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public List<InventoryService.AssignmentView> myAssignments(Authentication auth,
      @PathVariable UUID institutionId) {
    return service.listMyAssignments(ActorResolver.actorId(auth), institutionId);
  }

  @PostMapping("/assignments/{assignmentId}/receive")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public VialTransfer.Assignment receive(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID assignmentId, @Valid @RequestBody ReceiveRequest request) {
    return service.receive(ActorResolver.actorId(auth), institutionId, assignmentId, request.vials());
  }

  @PostMapping("/assignments")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public ResponseEntity<VialTransfer.Assignment> dispatch(Authentication auth,
      @PathVariable UUID institutionId, @Valid @RequestBody DispatchRequest request) {
    var assignment = service.dispatch(ActorResolver.actorId(auth), institutionId, request.movementId(),
        request.assignmentId(), request.lotId(), request.vaccinatorId(), request.vials(),
        request.occurredAt(), request.note(), request.campaignId());
    return ResponseEntity.status(HttpStatus.CREATED).body(assignment);
  }

  @ExceptionHandler(DataIntegrityViolationException.class)
  public ResponseEntity<ErrorResponse> conflict(DataIntegrityViolationException ignored) {
    return ResponseEntity.status(HttpStatus.CONFLICT).body(new ErrorResponse("INVENTORY_CONFLICT",
        "La operacion entra en conflicto con datos existentes o referencias invalidas; verifica antes de reintentar."));
  }
}
