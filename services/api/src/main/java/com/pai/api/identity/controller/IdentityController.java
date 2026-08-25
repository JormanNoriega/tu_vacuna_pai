package com.pai.api.identity.controller;

import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.pai.api.identity.dto.MeResponse;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.IdentityService;

@RestController
@RequestMapping("/api/v1")
public class IdentityController {

    private final IdentityService identityService;

    public IdentityController(IdentityService identityService) {
        this.identityService = identityService;
    }

    @GetMapping("/me")
    public ResponseEntity<MeResponse> me(Authentication authentication) {
        AuthorizedUser principal = (AuthorizedUser) authentication.getPrincipal();
        UUID userId = principal.getId();
        return ResponseEntity.ok(identityService.getMe(userId));
    }
}