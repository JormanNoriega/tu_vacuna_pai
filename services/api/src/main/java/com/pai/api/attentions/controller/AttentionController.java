package com.pai.api.attentions.controller;

import com.pai.api.attentions.dto.AppliedDoseResponse;
import com.pai.api.attentions.dto.AttentionResponse;
import com.pai.api.attentions.dto.CancelAttentionRequest;
import com.pai.api.attentions.dto.CancelDoseRequest;
import com.pai.api.attentions.dto.CreateAttentionRequest;
import com.pai.api.attentions.dto.RegisterDoseRequest;
import com.pai.api.attentions.dto.UpdateAttentionRequest;
import com.pai.api.attentions.service.AttentionService;
import com.pai.api.identity.service.AuthorizedUser;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Gestion clinica de atenciones y dosis aplicadas. La institucion y el
 * profesional se derivan del actor; el cliente nunca los envia. Las escrituras
 * que crean agregados admiten el header {@code Idempotency-Key} (D3).
 */
@RestController
@RequestMapping("/api/v1/attentions")
public class AttentionController {

  private final AttentionService service;

  public AttentionController(AttentionService service) {
    this.service = service;
  }

  @PostMapping
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public ResponseEntity<AttentionResponse> create(
      Authentication authentication,
      @RequestHeader(value = "Idempotency-Key", required = false) String operationId,
      @Valid @RequestBody CreateAttentionRequest request) {
    UUID actorId = actorId(authentication);
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(service.create(actorId, operationId, request));
  }

  @GetMapping("/{id}")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_READ')")
  public ResponseEntity<AttentionResponse> get(
      Authentication authentication, @PathVariable UUID id) {
    return ResponseEntity.ok(service.get(actorId(authentication), id));
  }

  @GetMapping
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_READ')")
  public ResponseEntity<List<AttentionResponse>> listByPatient(
      Authentication authentication, @RequestParam UUID patientId) {
    return ResponseEntity.ok(service.listByPatient(actorId(authentication), patientId));
  }

  @PutMapping("/{id}")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public ResponseEntity<AttentionResponse> update(
      Authentication authentication,
      @PathVariable UUID id,
      @Valid @RequestBody UpdateAttentionRequest request) {
    return ResponseEntity.ok(service.update(actorId(authentication), id, request));
  }

  @PostMapping("/{id}/complete")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public ResponseEntity<AttentionResponse> complete(
      Authentication authentication,
      @PathVariable UUID id,
      @RequestHeader(value = "Idempotency-Key", required = false) String operationId) {
    return ResponseEntity.ok(service.complete(actorId(authentication), operationId, id));
  }

  @PostMapping("/{id}/cancel")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public ResponseEntity<AttentionResponse> cancel(
      Authentication authentication,
      @PathVariable UUID id,
      @Valid @RequestBody CancelAttentionRequest request) {
    return ResponseEntity.ok(service.cancel(actorId(authentication), id, request));
  }

  @PostMapping("/{id}/doses")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public ResponseEntity<AppliedDoseResponse> registerDose(
      Authentication authentication,
      @PathVariable UUID id,
      @RequestHeader(value = "Idempotency-Key", required = false) String operationId,
      @Valid @RequestBody RegisterDoseRequest request) {
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(service.registerDose(actorId(authentication), operationId, id, request));
  }

  @PostMapping("/{id}/doses/{doseId}/cancel")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_CREATE')")
  public ResponseEntity<AppliedDoseResponse> cancelDose(
      Authentication authentication,
      @PathVariable UUID id,
      @PathVariable UUID doseId,
      @Valid @RequestBody CancelDoseRequest request) {
    return ResponseEntity.ok(service.cancelDose(actorId(authentication), id, doseId, request));
  }

  private UUID actorId(Authentication authentication) {
    return ((AuthorizedUser) authentication.getPrincipal()).getId();
  }
}
