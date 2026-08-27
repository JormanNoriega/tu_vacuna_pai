package com.pai.api.identity.controller;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
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
import com.pai.api.identity.dto.CreateVaccinatorRequest;
import com.pai.api.identity.dto.InstitutionResponse;
import com.pai.api.identity.dto.UpdateInstitutionConfigRequest;
import com.pai.api.identity.dto.UpdateInstitutionStatusRequest;
import com.pai.api.identity.dto.UpdateUserRolesRequest;
import com.pai.api.identity.dto.UpdateUserStatusRequest;
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

    @PutMapping("/institutions/{id}/config")
    @PreAuthorize("@authorization.hasPermission(authentication, 'INSTITUTION_WRITE')")
    public ResponseEntity<InstitutionResponse> updateInstitutionConfig(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateInstitutionConfigRequest request) {
        return ResponseEntity.ok(
            institutionService.updateConfig(id, request.offlineWindowHours()));
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

    @PostMapping("/users/vaccinators")
    @PreAuthorize("@authorization.hasPermission(authentication, 'USER_MANAGE')")
    public ResponseEntity<UserResponse> createVaccinator(
            Authentication authentication,
            @Valid @RequestBody CreateVaccinatorRequest request) {
        AuthorizedUser actor = (AuthorizedUser) authentication.getPrincipal();
        String accessToken = actor.getAccessToken();
        if (accessToken == null) {
            throw new IllegalStateException("No se pudo recuperar el access token.");
        }
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(userService.createVaccinator(actor.getId(), accessToken, request));
    }

    @GetMapping("/users")
    @PreAuthorize("@authorization.hasPermission(authentication, 'USER_MANAGE') "
        + "or @authorization.hasPermission(authentication, 'INSTITUTION_WRITE')")
    public ResponseEntity<List<UserResponse>> listUsers(
            Authentication authentication,
            @RequestParam UUID institutionId,
            @RequestParam(required = false) List<String> roles) {
        AuthorizedUser actor = (AuthorizedUser) authentication.getPrincipal();
        Set<String> roleSet = (roles == null || roles.isEmpty())
            ? null
            : new HashSet<>(roles);
        return ResponseEntity.ok(
            userService.listByInstitution(actor.getId(), institutionId, roleSet));
    }

    @PutMapping("/users/{id}/status")
    @PreAuthorize("@authorization.hasPermission(authentication, 'USER_MANAGE') "
        + "or @authorization.hasPermission(authentication, 'INSTITUTION_WRITE')")
    public ResponseEntity<UserResponse> updateUserStatus(
            Authentication authentication,
            @PathVariable UUID id,
            @Valid @RequestBody UpdateUserStatusRequest request) {
        AuthorizedUser actor = (AuthorizedUser) authentication.getPrincipal();
        return ResponseEntity.ok(userService.updateStatus(actor.getId(), id, request.status()));
    }

    @PutMapping("/users/{id}/roles")
    @PreAuthorize("@authorization.hasPermission(authentication, 'USER_MANAGE') "
        + "or @authorization.hasPermission(authentication, 'INSTITUTION_WRITE')")
    public ResponseEntity<UserResponse> updateUserRoles(
            Authentication authentication,
            @PathVariable UUID id,
            @Valid @RequestBody UpdateUserRolesRequest request) {
        AuthorizedUser actor = (AuthorizedUser) authentication.getPrincipal();
        return ResponseEntity.ok(userService.updateRoles(actor.getId(), id, request.roles()));
    }
}
