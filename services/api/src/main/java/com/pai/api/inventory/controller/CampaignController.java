package com.pai.api.inventory.controller;

import com.pai.api.inventory.service.CampaignService;
import com.pai.api.shared.exceptions.ErrorResponse;
import com.pai.api.shared.security.ActorResolver;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/institutions/{institutionId}/inventory/campaigns")
@ConditionalOnProperty(name = "app.inventory.api-enabled", havingValue = "true")
public class CampaignController {
  private final CampaignService service;
  public CampaignController(CampaignService service) { this.service = service; }

  public record CreateRequest(@NotNull UUID id, @NotBlank @Size(max = 200) String name,
      @NotBlank @Size(max = 200) String location, @NotNull LocalDate startsOn, @NotNull LocalDate endsOn) {}
  public record ParticipantRequest(@NotNull UUID vaccinatorId) {}

  @GetMapping
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public List<CampaignService.Campaign> list(Authentication auth, @PathVariable UUID institutionId) {
    return service.list(ActorResolver.actorId(auth), institutionId);
  }

  @PostMapping
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public ResponseEntity<InventoryController.CreatedId> create(Authentication auth, @PathVariable UUID institutionId,
      @Valid @RequestBody CreateRequest request) {
    service.create(ActorResolver.actorId(auth), institutionId, request.id(), request.name(), request.location(),
        request.startsOn(), request.endsOn());
    return ResponseEntity.status(HttpStatus.CREATED).body(new InventoryController.CreatedId(request.id()));
  }

  @GetMapping("/{campaignId}/participants")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_READ')")
  public List<CampaignService.Participant> participants(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID campaignId) {
    return service.participants(ActorResolver.actorId(auth), institutionId, campaignId);
  }

  @PostMapping("/{campaignId}/participants")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public ResponseEntity<Void> addParticipant(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID campaignId, @Valid @RequestBody ParticipantRequest request) {
    service.addParticipant(ActorResolver.actorId(auth), institutionId, campaignId, request.vaccinatorId());
    return ResponseEntity.noContent().build();
  }

  @PostMapping("/{campaignId}/finish")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public ResponseEntity<Void> finish(Authentication auth, @PathVariable UUID institutionId, @PathVariable UUID campaignId) {
    service.finish(ActorResolver.actorId(auth), institutionId, campaignId);
    return ResponseEntity.noContent().build();
  }

  @ExceptionHandler(DataIntegrityViolationException.class)
  public ResponseEntity<ErrorResponse> conflict(DataIntegrityViolationException ignored) {
    return ResponseEntity.status(HttpStatus.CONFLICT).body(new ErrorResponse("CAMPAIGN_CONFLICT",
        "La jornada ya existe o sus datos entran en conflicto; verifica la lista antes de reintentar."));
  }
}
