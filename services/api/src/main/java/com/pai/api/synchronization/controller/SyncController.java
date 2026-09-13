package com.pai.api.synchronization.controller;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.synchronization.dto.SyncPullResponse;
import com.pai.api.synchronization.dto.SyncPushRequest;
import com.pai.api.synchronization.dto.SyncPushResponse;
import com.pai.api.synchronization.service.SyncPullService;
import com.pai.api.synchronization.service.SyncPushService;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Transporte HTTP del motor de sincronizacion. La semantica vive en
 * {@code docs/synchronization/sync-contract.md} y el contrato de transporte en
 * {@code docs/api/openapi.yaml}.
 *
 * <p>No se anota {@code @PreAuthorize} por permiso: los comandos de un mismo
 * batch requieren permisos distintos, asi que el permiso se valida por operacion
 * en {@link SyncPushService} para poder rechazarla con {@code PERMISSION_DENIED}
 * sin abortar el batch. El endpoint solo exige autenticacion.
 */
@RestController
@RequestMapping("/api/v1/sync")
public class SyncController {

    private final SyncPushService pushService;
    private final SyncPullService pullService;

    public SyncController(SyncPushService pushService, SyncPullService pullService) {
        this.pushService = pushService;
        this.pullService = pullService;
    }

    @PostMapping("/push")
    public ResponseEntity<SyncPushResponse> push(
            Authentication authentication, @Valid @RequestBody SyncPushRequest request) {
        return ResponseEntity.ok(pushService.push(actorId(authentication), request));
    }

    @GetMapping("/pull")
    public ResponseEntity<SyncPullResponse> pull(
            Authentication authentication,
            @RequestParam(value = "since", required = false) String since,
            @RequestParam(value = "limit", required = false) Integer limit) {
        return ResponseEntity.ok(pullService.pull(actorId(authentication), since, limit));
    }

    private UUID actorId(Authentication authentication) {
        return ((AuthorizedUser) authentication.getPrincipal()).getId();
    }
}
