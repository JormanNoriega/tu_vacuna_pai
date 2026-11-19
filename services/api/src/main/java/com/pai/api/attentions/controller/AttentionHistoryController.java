package com.pai.api.attentions.controller;

import com.pai.api.attentions.service.AttentionHistoryService;
import com.pai.api.shared.security.ActorResolver;
import java.time.Instant;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/attention-history")
public class AttentionHistoryController {
  private final AttentionHistoryService service;

  public AttentionHistoryController(AttentionHistoryService service) {
    this.service = service;
  }

  @GetMapping
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_READ')")
  public AttentionHistoryService.HistoryPage history(
      Authentication authentication, @RequestParam Instant from, @RequestParam Instant to,
      @RequestParam(defaultValue = "0") int page) {
    return service.history(ActorResolver.resolve(authentication), from, to, page);
  }
}
