package com.pai.api.geography;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.RoleCodes;
import com.pai.api.shared.exceptions.ScopeViolationException;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.Authentication;
import org.springframework.web.server.ResponseStatusException;

class GeographyControllerTest {
  private final GeographyAggregation aggregation = mock(GeographyAggregation.class);
  private final GeographyController controller =
      new GeographyController(aggregation, List.of(7, 30, 90), 30);

  private Authentication authentication(List<String> roles, InstitutionEntity institution) {
    AuthorizedUser actor = mock(AuthorizedUser.class);
    when(actor.getRoles()).thenReturn(roles);
    when(actor.getInstitution()).thenReturn(institution);
    Authentication authentication = mock(Authentication.class);
    when(authentication.getPrincipal()).thenReturn(actor);
    return authentication;
  }

  @Test
  void rejectsVaccinatorAndMixedSuperAdminBeforeQuerying() {
    InstitutionEntity institution = mock(InstitutionEntity.class);
    for (List<String> roles : List.of(
        List.of(RoleCodes.VACCINATOR),
        List.of(RoleCodes.ADMIN_INSTITUTION, RoleCodes.VACCINATOR),
        List.of(RoleCodes.ADMIN_INSTITUTION, RoleCodes.SUPER_ADMIN))) {
      assertThatThrownBy(() -> controller.attentions(authentication(roles, institution), 30))
          .isInstanceOf(ScopeViolationException.class);
    }
    verify(aggregation, never()).load(
        org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.anyInt(),
        org.mockito.ArgumentMatchers.any());
  }

  @Test
  void rejectsUnapprovedPeriod() {
    InstitutionEntity institution = mock(InstitutionEntity.class);
    when(institution.getId()).thenReturn(UUID.randomUUID());
    Authentication auth = authentication(
        List.of(RoleCodes.ADMIN_INSTITUTION), institution);
    assertThatThrownBy(() -> controller.attentions(auth, 8))
        .isInstanceOf(ResponseStatusException.class);
  }

  @Test
  void usesActorsInstitutionAndDisablesHttpCaching() {
    InstitutionEntity institution = mock(InstitutionEntity.class);
    UUID id = UUID.randomUUID();
    when(institution.getId()).thenReturn(id);
    when(aggregation.load(org.mockito.ArgumentMatchers.eq(id), org.mockito.ArgumentMatchers.eq(30),
        org.mockito.ArgumentMatchers.any(LocalDate.class)))
        .thenReturn(new GeographyResponse(30, LocalDate.of(2026, 11, 25), Instant.EPOCH, List.of()));
    var response = controller.attentions(
        authentication(List.of(RoleCodes.ADMIN_INSTITUTION), institution), 30);
    assertThat(response.getHeaders().getCacheControl()).contains("no-store");
    assertThat(response.getBody().generatedAt()).isEqualTo(Instant.EPOCH);
  }
}
