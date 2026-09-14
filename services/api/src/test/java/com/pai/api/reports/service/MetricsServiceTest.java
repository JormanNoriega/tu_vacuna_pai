package com.pai.api.reports.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.pai.api.attentions.entity.AppliedDoseEntity;
import com.pai.api.attentions.entity.AttentionEntity;
import com.pai.api.attentions.repository.AppliedDoseRepository;
import com.pai.api.attentions.repository.AttentionRepository;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.reports.dto.MetricsSummaryResponse;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class MetricsServiceTest {

  private static final UUID INSTITUTION_ID =
      UUID.fromString("11111111-1111-1111-1111-111111111111");
  private static final UUID ACTOR_ID = UUID.fromString("22222222-2222-2222-2222-222222222222");

  @Mock
  private AttentionRepository attentions;

  @Mock
  private AppliedDoseRepository doses;

  @Mock
  private DataScope dataScope;

  private MetricsService service;

  @BeforeEach
  void setUp() {
    service = new MetricsService(attentions, doses, dataScope);
  }

  @Test
  void resume_pacientes_y_dosis_no_anuladas_de_la_institucion() {
    AuthorizedUser actor = actor();
    when(dataScope.resolveInstitutionId(actor, INSTITUTION_ID)).thenReturn(INSTITUTION_ID);
    when(attentions.countDistinctPatientsByInstitutionId(
            INSTITUTION_ID, AttentionEntity.Status.CANCELLED))
        .thenReturn(12L);
    when(doses.countByInstitutionId(INSTITUTION_ID, AppliedDoseEntity.Status.CANCELLED))
        .thenReturn(34L);

    MetricsSummaryResponse summary = service.summary(actor);

    assertThat(summary.patientsAttended()).isEqualTo(12L);
    assertThat(summary.dosesApplied()).isEqualTo(34L);
  }

  private AuthorizedUser actor() {
    return new AuthorizedUser(
        ACTOR_ID,
        "vac@hosp.a",
        "Ana Vacunadora",
        new InstitutionEntity(
            INSTITUTION_ID,
            "HOSP-A",
            "Hospital A",
            InstitutionEntity.Status.ACTIVE,
            (short) 72,
            Instant.now(),
            Instant.now()),
        List.of("VACCINATOR"),
        List.of("ATTENTION_READ"),
        Instant.now());
  }
}
