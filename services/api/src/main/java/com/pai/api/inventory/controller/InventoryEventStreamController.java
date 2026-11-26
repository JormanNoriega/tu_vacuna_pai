package com.pai.api.inventory.controller;

import com.pai.api.inventory.service.InventoryEventStream;
import com.pai.api.shared.security.ActorResolver;
import java.util.UUID;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@RestController
@RequestMapping("/api/v1/institutions/{institutionId}/inventory")
@ConditionalOnProperty(name = "app.inventory.api-enabled", havingValue = "true")
public class InventoryEventStreamController {
  private final InventoryEventStream stream;
  private final JwtDecoder decoder;
  public InventoryEventStreamController(InventoryEventStream stream, JwtDecoder decoder) {
    this.stream = stream;
    this.decoder = decoder;
  }

  @GetMapping(value = "/events", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
  public SseEmitter events(Authentication auth, @PathVariable UUID institutionId,
      @RequestHeader("Authorization") String authorization) {
    Jwt jwt = decoder.decode(ActorResolver.bearerToken(authorization));
    UUID actor = ActorResolver.actorId(auth);
    if (jwt.getExpiresAt() == null || !actor.toString().equals(jwt.getSubject())) {
      throw new com.pai.api.shared.exceptions.PermissionDeniedException("Token sin vencimiento.");
    }
    return stream.subscribe(actor, institutionId, jwt.getExpiresAt());
  }
}
