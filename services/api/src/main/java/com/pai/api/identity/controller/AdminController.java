package com.pai.api.identity.controller;

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
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.pai.api.identity.dto.CreateInstitutionAdminRequest;
import com.pai.api.identity.dto.CreateInstitutionRequest;
import com.pai.api.identity.dto.InstitutionResponse;
import com.pai.api.identity.dto.UpdateInstitutionStatusRequest;
import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.InstitutionService;
import com.pai.api.identity.service.UserService;

import jakarta.validation.Valid;

/**
 * Administracion global ({@code SUPER_ADMIN}) y de institucion
 * ({@code ADMIN_INSTITUTION}). Ningun metodo consulta repositorios ni devuelve
 * entidades JPA; delegan en los servicios y responden con DTOs (ADR-006).
 */
@RestController
@RequestMapping("/api/v1")
public class AdminController {

    private final InstitutionService institutionService;
    private final UserService userService;

    public AdminController(InstitutionService institutionService, UserService userService) {
        this.institutionService = institutionService;
        this.userService = userService;
    }

    @PostMapping("/institutions")
    @PreAuthorize("@authorization.hasPermission(authentication, 'INSTITUTION_WRITE')")
    public ResponseEntity<InstitutionResponse> createInstitution(
            @Valid @RequestBody CreateInstitutionRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(institutionService.create(request));
    }

    @GetMapping("/institutions")
    @PreAuthorize("@authorization.hasPermission(authentication, 'INSTITUTION_WRITE')")
    public ResponseEntity<List<InstitutionResponse>> listInstitutions() {
        return ResponseEntity.ok(institutionService.list());
    }

    @PutMapping("/institutions/{id}/status")
    @PreAuthorize("@authorization.hasPermission(authentication, 'INSTITUTION_WRITE')")
    public ResponseEntity<InstitutionResponse> updateInstitutionStatus(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateInstitutionStatusRequest request) {
        return ResponseEntity.ok(institutionService.updateStatus(id, request.status()));
    }

    @PostMapping("/users/institution-admins")
    @PreAuthorize("@authorization.hasPermission(authentication, 'INSTITUTION_WRITE')")
    public ResponseEntity<UserResponse> createInstitutionAdmin(
            Authentication authentication,
            @Valid @RequestBody CreateInstitutionAdminRequest request) {
        AuthorizedUser actor = (AuthorizedUser) authentication.getPrincipal();
        String accessToken = actor.getAccessToken();
        if (accessToken == null) {
            throw new IllegalStateException("No se pudo recuperar el access token.");
        }
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(userService.createInstitutionAdmin(actor.getId(), accessToken, request));
    }

    @GetMapping("/users")
    @PreAuthorize("@authorization.hasPermission(authentication, 'USER_MANAGE') "
        + "or @authorization.hasPermission(authentication, 'INSTITUTION_WRITE')")
    public ResponseEntity<List<UserResponse>> listUsers(
            Authentication authentication,
            @RequestParam UUID institutionId) {
        AuthorizedUser actor = (AuthorizedUser) authentication.getPrincipal();
        return ResponseEntity.ok(
            userService.listByInstitution(actor.getId(), institutionId));
    }
}
