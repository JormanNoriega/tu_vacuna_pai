package com.pai.api.reports.controller;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.reports.export.ExportedReport;
import com.pai.api.reports.export.ReportFormat;
import com.pai.api.reports.service.RegistroDiarioExportService;
import com.pai.api.shared.security.ActorResolver;
import java.time.Instant;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Exportacion de reportes PAI. Backend-only por ahora (el cliente movil aun no lo
 * consume). La institucion se deriva del actor; el cliente nunca la envia
 * (ADR-007).
 */
@RestController
@RequestMapping("/api/v1/reports")
public class ReportController {

  private final RegistroDiarioExportService service;

  public ReportController(RegistroDiarioExportService service) {
    this.service = service;
  }

  @GetMapping("/registro-diario")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_READ')")
  public ResponseEntity<byte[]> registroDiario(
      Authentication authentication,
      @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
      @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
      @RequestParam(defaultValue = "xlsx") String format) {
    AuthorizedUser actor = ActorResolver.resolve(authentication);
    ExportedReport report = service.export(actor, from, to, ReportFormat.from(format));
    return ResponseEntity.ok()
        .header(
            HttpHeaders.CONTENT_DISPOSITION,
            "attachment; filename=\"" + report.filename() + "\"")
        .contentType(MediaType.parseMediaType(report.contentType()))
        .body(report.content());
  }
}
