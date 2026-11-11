package com.pai.api.inventory.controller;

import com.pai.api.inventory.service.InstallationReservationService;
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

/** API experimental: no constituye autorizacion para consumo offline. */
@RestController
@RequestMapping("/api/v1/institutions/{institutionId}/inventory")
@ConditionalOnProperty(name = {"app.inventory.api-enabled", "app.inventory.reservations-enabled"}, havingValue = "true")
public class InstallationReservationController {
  private final InstallationReservationService service;
  public InstallationReservationController(InstallationReservationService service) { this.service = service; }
  public record RegisterRequest(@NotNull UUID id, @NotBlank @Size(max = 80) String label) {}
  public record ReserveRequest(@NotNull UUID id, @NotNull UUID assignmentId,
      @NotNull UUID installationId, @Positive int vials) {}

  @PostMapping("/installations")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public ResponseEntity<InventoryController.CreatedId> register(Authentication auth, @PathVariable UUID institutionId,
      @Valid @RequestBody RegisterRequest request) {
    service.register(ActorResolver.actorId(auth), institutionId, request.id(), request.label());
    return ResponseEntity.status(HttpStatus.CREATED).body(new InventoryController.CreatedId(request.id()));
  }

  @GetMapping("/installations")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public List<InstallationReservationService.Installation> list(Authentication auth, @PathVariable UUID institutionId) {
    return service.list(ActorResolver.actorId(auth), institutionId);
  }

  @PostMapping("/installation-reservations")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public ResponseEntity<InstallationReservationService.Reservation> reserve(Authentication auth,
      @PathVariable UUID institutionId, @Valid @RequestBody ReserveRequest request) {
    return ResponseEntity.status(HttpStatus.CREATED).body(service.reserve(ActorResolver.actorId(auth), institutionId,
        request.id(), request.assignmentId(), request.installationId(), request.vials()));
  }

  @GetMapping("/installation-reservations")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public List<InstallationReservationService.Reservation> reservations(Authentication auth, @PathVariable UUID institutionId) {
    return service.listReservations(ActorResolver.actorId(auth), institutionId);
  }

  @ExceptionHandler(DataIntegrityViolationException.class)
  public ResponseEntity<ErrorResponse> conflict(DataIntegrityViolationException ignored) {
    return ResponseEntity.status(HttpStatus.CONFLICT).body(new ErrorResponse("INSTALLATION_RESERVATION_CONFLICT",
        "El identificador ya existe o hay un conflicto; revisa antes de reintentar."));
  }
}
