package com.pai.api.identity.controller;

import com.pai.api.identity.dto.MeResponse;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.shared.security.ActorResolver;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class IdentityController {

  private final IdentityService identityService;

  public IdentityController(IdentityService identityService) {
    this.identityService = identityService;
  }

  @GetMapping("/me")
  public ResponseEntity<MeResponse> me(Authentication authentication) {
    return ResponseEntity.ok(identityService.getMe(ActorResolver.actorId(authentication)));
  }
}
