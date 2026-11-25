package com.pai.api.inventory.controller;

import com.pai.api.inventory.domain.VialTransfer;
import com.pai.api.inventory.service.InventoryService;
import com.pai.api.inventory.service.InventoryReceiptWorkflow;
import com.pai.api.shared.exceptions.ErrorResponse;
import com.pai.api.shared.security.ActorResolver;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.AssertTrue;
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
  private final InventoryReceiptWorkflow receiptWorkflow;

  public InventoryController(InventoryService service, InventoryReceiptWorkflow receiptWorkflow) {
    this.service = service;
    this.receiptWorkflow = receiptWorkflow;
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
  public record PartialReceiveRequest(@NotNull UUID id, @NotNull @PositiveOrZero Integer vials,
      @Size(max = 1000) String note) {}
  public record ResolveDifferenceRequest(@NotNull UUID id, @NotBlank String kind,
      @NotNull @Positive Integer vials, @NotBlank @Size(max = 1000) String note) {}
  public record RegularizeDepotRequest(@NotNull UUID id, @NotNull @Positive Integer vials,
      @NotBlank @Size(max = 1000) String note, @AssertTrue boolean physicalAndSuitable) {}

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

  @GetMapping("/pending-follow-ups")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public List<InventoryService.PendingFollowUp> pendingFollowUps(Authentication auth,
      @PathVariable UUID institutionId) {
    return service.listPendingFollowUps(ActorResolver.actorId(auth), institutionId);
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

  @GetMapping("/assignments/{assignmentId}/historical-custody-review")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public InventoryService.HistoricalReview historicalCustodyReview(Authentication auth,
      @PathVariable UUID institutionId, @PathVariable UUID assignmentId) {
    return service.reviewHistoricalCustody(ActorResolver.actorId(auth), institutionId, assignmentId);
  }

  @GetMapping("/assignments/{assignmentId}/conciliation")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public InventoryService.DeliveryConciliation conciliation(Authentication auth,
      @PathVariable UUID institutionId, @PathVariable UUID assignmentId) {
    return service.reviewConciliation(ActorResolver.actorId(auth), institutionId, assignmentId);
  }

  @GetMapping("/my-assignments")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public List<InventoryService.AssignmentView> myAssignments(Authentication auth,
      @PathVariable UUID institutionId) {
    return service.listMyAssignments(ActorResolver.actorId(auth), institutionId);
  }

  @GetMapping("/vaccines/{vaccineId}/my-received-lots")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public List<InventoryService.ReceivedLot> myReceivedLots(Authentication auth,
      @PathVariable UUID institutionId, @PathVariable UUID vaccineId) {
    return service.listMyReceivedLots(ActorResolver.actorId(auth), institutionId, vaccineId);
  }

  @GetMapping("/vaccines/{vaccineId}/my-uncommitted-received-lots")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public List<InventoryService.ReceivedLot> myUncommittedReceivedLots(Authentication auth,
      @PathVariable UUID institutionId, @PathVariable UUID vaccineId) {
    return service.listMyUncommittedReceivedLots(ActorResolver.actorId(auth), institutionId, vaccineId);
  }

  @PostMapping("/assignments/{assignmentId}/receive")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public VialTransfer.Assignment receive(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID assignmentId, @Valid @RequestBody ReceiveRequest request) {
    return service.receive(ActorResolver.actorId(auth), institutionId, assignmentId, request.vials());
  }

  @PostMapping("/assignments/{assignmentId}/receipts")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public InventoryService.ReceiptResult receivePartial(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID assignmentId, @Valid @RequestBody PartialReceiveRequest request) {
    return receiptWorkflow.receive(ActorResolver.actorId(auth), institutionId, assignmentId,
        request.id(), request.vials(), request.note());
  }

  @GetMapping("/assignments/{assignmentId}/difference-resolutions")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public List<InventoryService.DifferenceResolution> differenceResolutions(Authentication auth,
      @PathVariable UUID institutionId, @PathVariable UUID assignmentId) {
    return service.listDifferenceResolutions(ActorResolver.actorId(auth), institutionId, assignmentId);
  }

  @PostMapping("/assignments/{assignmentId}/difference-resolutions")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public InventoryService.DifferenceResolution resolveDifference(Authentication auth,
      @PathVariable UUID institutionId, @PathVariable UUID assignmentId,
      @Valid @RequestBody ResolveDifferenceRequest request) {
    return service.resolveDifference(ActorResolver.actorId(auth), institutionId, assignmentId,
        request.id(), request.kind(), request.vials(), request.note());
  }

  @GetMapping("/difference-resolutions/{resolutionId}/depot-regularizations")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public List<InventoryService.DepotRegularization> depotRegularizations(Authentication auth,
      @PathVariable UUID institutionId, @PathVariable UUID resolutionId) {
    return service.listDepotRegularizations(ActorResolver.actorId(auth), institutionId, resolutionId);
  }

  @PostMapping("/difference-resolutions/{resolutionId}/depot-regularizations")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public InventoryService.DepotRegularization regularizeDepot(Authentication auth,
      @PathVariable UUID institutionId, @PathVariable UUID resolutionId,
      @Valid @RequestBody RegularizeDepotRequest request) {
    return service.regularizeDepot(ActorResolver.actorId(auth), institutionId, resolutionId,
        request.id(), request.vials(), request.note(), request.physicalAndSuitable());
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
