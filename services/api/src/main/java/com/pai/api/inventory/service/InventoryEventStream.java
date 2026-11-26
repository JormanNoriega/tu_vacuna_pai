package com.pai.api.inventory.service;

import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import java.io.IOException;
import java.time.Instant;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionalEventListener;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/** Suscripciones efímeras locales a esta instancia; no es una cola persistente. */
@Service
public class InventoryEventStream {
  private final IdentityService identity;
  private final DataScope scope;
  private final Set<Subscription> subscriptions = ConcurrentHashMap.newKeySet();

  public InventoryEventStream(IdentityService identity, DataScope scope) {
    this.identity = identity;
    this.scope = scope;
  }

  public SseEmitter subscribe(UUID actor, UUID institution, Instant expires) {
    if (!expires.isAfter(Instant.now())) {
      throw new com.pai.api.shared.exceptions.PermissionDeniedException("Token vencido.");
    }
    var user = identity.resolve(actor);
    scope.resolveInstitutionId(user, institution);
    if (!user.hasPermission("ATTENTION_CREATE") && !user.hasPermission("INVENTORY_READ")) {
      throw new com.pai.api.shared.exceptions.PermissionDeniedException("Permiso insuficiente.");
    }
    long timeout = Math.max(1, Math.min(900_000, expires.toEpochMilli() - System.currentTimeMillis()));
    var emitter = new SseEmitter(timeout);
    var subscription = new Subscription(actor, institution, expires, emitter);
    subscriptions.add(subscription);
    emitter.onCompletion(() -> subscriptions.remove(subscription));
    emitter.onTimeout(() -> { subscriptions.remove(subscription); emitter.complete(); });
    emitter.onError(error -> subscriptions.remove(subscription));
    try {
      emitter.send(SseEmitter.event().name("ready").data("ok"));
    } catch (IOException | IllegalStateException ex) {
      subscriptions.remove(subscription);
    }
    return emitter;
  }

  @TransactionalEventListener
  public void onChange(InventoryChange change) {
    for (var subscription : subscriptions) {
      if (!subscription.institution().equals(change.institutionId())) continue;
      try {
        if (!subscription.expires().isAfter(Instant.now())) {
          subscriptions.remove(subscription);
          subscription.emitter().complete();
          continue;
        }
        var user = identity.resolve(subscription.actor());
        scope.resolveInstitutionId(user, change.institutionId());
        boolean allowed = switch (change.type()) {
          case "DELIVERY_CREATED" -> subscription.actor().equals(change.vaccinatorId())
              && user.hasPermission("ATTENTION_CREATE");
          case "RETURN_DECLARED" -> user.hasPermission("INVENTORY_READ");
          default -> false;
        };
        if (allowed) {
          subscription.emitter().send(SseEmitter.event().name("inventory-change")
              .data(new Notice(change.type(), change.assignmentId(), change.eventId())));
        }
      } catch (RuntimeException | IOException ex) {
        subscriptions.remove(subscription);
        try { subscription.emitter().complete(); } catch (RuntimeException ignored) { }
      }
    }
  }

  public record Notice(String type, UUID assignmentId, UUID eventId) {}
  private record Subscription(UUID actor, UUID institution, Instant expires, SseEmitter emitter) {}
}
