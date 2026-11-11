package com.pai.api.inventory.controller;

import com.pai.api.inventory.security.InstallationChallengeService;
import com.pai.api.inventory.security.InstallationKeyService;
import com.pai.api.shared.security.ActorResolver;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.NotBlank;
import java.util.UUID;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

/** Interfaz experimental de alta y revocacion; no habilita consumo ni recuperacion. */
@RestController
@RequestMapping("/api/v1/institutions/{institutionId}/inventory/installations/{installationId}/key")
@ConditionalOnProperty(name = {"app.inventory.api-enabled", "app.inventory.reservations-enabled",
    "app.inventory.installation-keys-enabled"}, havingValue = "true")
public class InstallationKeyController {
  private final InstallationKeyService service;
  public InstallationKeyController(InstallationKeyService service) { this.service = service; }
  public record BeginRequest(@NotNull @Size(min = 1, max = 128) byte[] publicKey) {}
  public record CompleteRequest(@NotNull UUID challengeId, @NotNull @Size(min = 1, max = 128) byte[] publicKey,
      @NotNull @Size(min = 64, max = 64) byte[] signature) {}
  public record RevokeRequest(@NotBlank @Size(max = 1000) String note) {}

  @PostMapping("/challenges")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public ResponseEntity<InstallationChallengeService.Challenge> begin(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID installationId, @Valid @RequestBody BeginRequest request) {
    return ResponseEntity.ok().cacheControl(CacheControl.noStore())
        .body(service.begin(ActorResolver.actorId(auth), institutionId, installationId, request.publicKey()));
  }

  @PostMapping("/confirm")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public ResponseEntity<Void> complete(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID installationId, @Valid @RequestBody CompleteRequest request) {
    boolean ok = service.complete(ActorResolver.actorId(auth), institutionId, installationId,
        request.challengeId(), request.publicKey(), request.signature());
    return ResponseEntity.status(ok ? HttpStatus.NO_CONTENT : HttpStatus.BAD_REQUEST).build();
  }

  @PostMapping("/revoke")
  @PreAuthorize("@authorization.hasPermission(authentication, 'INVENTORY_WRITE')")
  public ResponseEntity<Void> revoke(Authentication auth, @PathVariable UUID institutionId,
      @PathVariable UUID installationId, @Valid @RequestBody RevokeRequest request) {
    service.revoke(ActorResolver.actorId(auth), institutionId, installationId, request.note());
    return ResponseEntity.noContent().build();
  }
}
