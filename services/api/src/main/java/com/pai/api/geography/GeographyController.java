package com.pai.api.geography;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.RoleCodes;
import com.pai.api.shared.exceptions.ScopeViolationException;
import com.pai.api.shared.security.ActorResolver;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@RestController
@RequestMapping("/api/v1/geography")
@ConditionalOnProperty(name = "app.geography.enabled", havingValue = "true")
class GeographyController {
  private final GeographyAggregation aggregation;
  private final List<Integer> allowedPeriods;
  private final int defaultPeriod;

  GeographyController(GeographyAggregation aggregation,
      @Value("${app.geography.allowed-periods:7,30,90}") List<Integer> allowedPeriods,
      @Value("${app.geography.default-period:30}") int defaultPeriod) {
    if (allowedPeriods.isEmpty() || allowedPeriods.stream().anyMatch(days -> days == null || days < 1)
        || !allowedPeriods.contains(defaultPeriod)) {
      throw new IllegalArgumentException("Períodos geográficos inválidos");
    }
    this.aggregation = aggregation;
    this.allowedPeriods = List.copyOf(allowedPeriods);
    this.defaultPeriod = defaultPeriod;
  }

  @GetMapping("/attentions")
  @PreAuthorize("@authorization.hasPermission(authentication, 'ATTENTION_READ')")
  ResponseEntity<GeographyResponse> attentions(Authentication authentication,
      @RequestParam(required = false) Integer days) {
    AuthorizedUser actor = ActorResolver.resolve(authentication);
    List<String> roles = actor.getRoles();
    if (roles == null || !roles.contains(RoleCodes.ADMIN_INSTITUTION)
        || roles.contains(RoleCodes.SUPER_ADMIN) || roles.contains(RoleCodes.VACCINATOR)
        || actor.getInstitution() == null || actor.getInstitution().getId() == null) {
      throw new ScopeViolationException("El visor está reservado al administrador institucional.");
    }
    int period = days == null ? defaultPeriod : days;
    if (!allowedPeriods.contains(period)) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Período no permitido.");
    }
    GeographyResponse response = aggregation.load(actor.getInstitution().getId(), period,
        LocalDate.now(ZoneId.of("America/Bogota")));
    return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(response);
  }
}
