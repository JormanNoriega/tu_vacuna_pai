package com.pai.api.attentions.service;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.attentions.repository.AppliedDoseRepository;
import com.pai.api.attentions.repository.AttentionRepository;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.RoleCodes;
import com.pai.api.reports.service.PatientIdentityQuery;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.SliceImpl;
import org.springframework.web.server.ResponseStatusException;

class AttentionHistoryServiceTest {
  private final AttentionRepository attentions = mock(AttentionRepository.class);
  private final DataScope scope = mock(DataScope.class);
  private final AttentionHistoryService service = new AttentionHistoryService(
      attentions, mock(AppliedDoseRepository.class), mock(UserRepository.class),
      mock(PatientIdentityQuery.class), scope);
  private final UUID institution = UUID.randomUUID();
  private final UUID user = UUID.randomUUID();
  private final Instant from = Instant.parse("2026-01-01T00:00:00Z");
  private final Instant to = Instant.parse("2026-02-01T00:00:00Z");

  @Test
  void adminUsesInstitutionScopeAndBoundedPages() {
    AuthorizedUser actor = mock(AuthorizedUser.class);
    when(actor.getRoles()).thenReturn(List.of(RoleCodes.ADMIN_INSTITUTION));
    when(scope.institutionOf(actor)).thenReturn(institution);
    when(attentions.historyPage(eq(institution), eq(from), eq(to), any()))
        .thenReturn(new SliceImpl<>(List.of()));
    service.history(actor, from, to, 2);
    verify(attentions).historyPage(institution, from, to, PageRequest.of(2, 10));
  }

  @Test
  void vaccinatorCannotRequestOtherProfessionals() {
    AuthorizedUser actor = mock(AuthorizedUser.class);
    when(actor.getRoles()).thenReturn(List.of(RoleCodes.VACCINATOR));
    when(actor.getId()).thenReturn(user);
    when(scope.institutionOf(actor)).thenReturn(institution);
    when(attentions.personalHistoryPage(eq(institution), eq(user), eq(from), eq(to), any()))
        .thenReturn(new SliceImpl<>(List.of()));
    service.history(actor, from, to, 0);
    verify(attentions).personalHistoryPage(institution, user, from, to, PageRequest.of(0, 10));
  }

  @Test
  void rejectsInvalidOrUnboundedRanges() {
    AuthorizedUser actor = mock(AuthorizedUser.class);
    assertThatThrownBy(() -> service.history(actor, to, from, 0))
        .isInstanceOf(ResponseStatusException.class);
    assertThatThrownBy(() -> service.history(actor, from, from.plusSeconds(368L * 86400), 0))
        .isInstanceOf(ResponseStatusException.class);
    assertThatThrownBy(() -> service.history(actor, from, to, -1))
        .isInstanceOf(ResponseStatusException.class);
  }
}
