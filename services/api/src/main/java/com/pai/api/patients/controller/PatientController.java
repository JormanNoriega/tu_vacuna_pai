package com.pai.api.patients.controller;

import com.pai.api.patients.dto.CreatePatientRequest;
import com.pai.api.patients.dto.PatientResponse;
import com.pai.api.patients.dto.PatientSummaryResponse;
import com.pai.api.patients.dto.UpdatePatientContactRequest;
import com.pai.api.patients.dto.UpdatePatientDemographicsRequest;
import com.pai.api.patients.dto.UpdatePatientIdentityRequest;
import com.pai.api.patients.dto.UpdatePatientMedicalHistoriesRequest;
import com.pai.api.patients.service.PatientService;
import com.pai.api.shared.security.ActorResolver;
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
 * Gestion clinica de pacientes. La institucion se deriva del actor en el
 * servicio; el cliente nunca la envia. Toda escritura admite el header
 * {@code Idempotency-Key} (operation_id) para reintentos seguros (D3).
 */
@RestController
@RequestMapping("/api/v1/patients")
public class PatientController {

  private final PatientService service;

  public PatientController(PatientService service) {
    this.service = service;
  }

  @PostMapping
  @PreAuthorize("@authorization.hasPermission(authentication, 'PATIENT_WRITE')")
  public ResponseEntity<PatientResponse> create(
      Authentication authentication,
      @RequestHeader(value = "Idempotency-Key", required = false) String operationId,
      @Valid @RequestBody CreatePatientRequest request) {
    UUID actorId = ActorResolver.actorId(authentication);
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(service.create(actorId, operationId, request));
  }

  @GetMapping("/{id}")
  @PreAuthorize("@authorization.hasPermission(authentication, 'PATIENT_READ')")
  public ResponseEntity<PatientResponse> get(Authentication authentication, @PathVariable UUID id) {
    UUID actorId = ActorResolver.actorId(authentication);
    return ResponseEntity.ok(service.get(actorId, id));
  }

  @GetMapping
  @PreAuthorize("@authorization.hasPermission(authentication, 'PATIENT_READ')")
  public ResponseEntity<List<PatientSummaryResponse>> search(
      Authentication authentication,
      @RequestParam(required = false) String documentType,
      @RequestParam String documentNumber) {
    UUID actorId = ActorResolver.actorId(authentication);
    return ResponseEntity.ok(service.search(actorId, documentType, documentNumber));
  }

  @PutMapping("/{id}/contact")
  @PreAuthorize("@authorization.hasPermission(authentication, 'PATIENT_WRITE')")
  public ResponseEntity<PatientResponse> updateContact(
      Authentication authentication,
      @PathVariable UUID id,
      @Valid @RequestBody UpdatePatientContactRequest request) {
    UUID actorId = ActorResolver.actorId(authentication);
    return ResponseEntity.ok(service.updateContact(actorId, id, request));
  }

  @PutMapping("/{id}/identity")
  @PreAuthorize("@authorization.hasPermission(authentication, 'PATIENT_WRITE')")
  public ResponseEntity<PatientResponse> updateIdentity(
      Authentication authentication,
      @PathVariable UUID id,
      @Valid @RequestBody UpdatePatientIdentityRequest request) {
    UUID actorId = ActorResolver.actorId(authentication);
    return ResponseEntity.ok(service.updateIdentity(actorId, id, request));
  }

  @PutMapping("/{id}/demographics")
  @PreAuthorize("@authorization.hasPermission(authentication, 'PATIENT_WRITE')")
  public ResponseEntity<PatientResponse> updateDemographics(
      Authentication authentication,
      @PathVariable UUID id,
      @Valid @RequestBody UpdatePatientDemographicsRequest request) {
    UUID actorId = ActorResolver.actorId(authentication);
    return ResponseEntity.ok(service.updateDemographics(actorId, id, request));
  }

  @PutMapping("/{id}/medical-histories")
  @PreAuthorize("@authorization.hasPermission(authentication, 'PATIENT_WRITE')")
  public ResponseEntity<PatientResponse> updateMedicalHistories(
      Authentication authentication,
      @PathVariable UUID id,
      @Valid @RequestBody UpdatePatientMedicalHistoriesRequest request) {
    UUID actorId = ActorResolver.actorId(authentication);
    return ResponseEntity.ok(service.updateMedicalHistories(actorId, id, request));
  }
}
