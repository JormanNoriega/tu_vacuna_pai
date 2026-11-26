package com.pai.api.attentions.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.pai.api.attentions.entity.AppliedDoseEntity;
import com.pai.api.attentions.entity.AttentionEntity;
import com.pai.api.attentions.repository.AppliedDoseRepository;
import com.pai.api.attentions.repository.AttentionRepository;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.reports.dto.StatisticsDashboardResponse;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class StatisticsQueryServiceTest {

  private static final UUID INSTITUTION_ID = UUID.fromString("11111111-1111-1111-1111-111111111111");
  private static final UUID PATIENT_ID = UUID.fromString("22222222-2222-2222-2222-222222222222");
  private static final UUID PROFESSIONAL_ID = UUID.fromString("33333333-3333-3333-3333-333333333333");
  private static final UUID ATTENTION_ID = UUID.fromString("44444444-4444-4444-4444-444444444444");
  private static final Instant FROM = Instant.parse("2025-03-10T00:00:00Z");
  private static final Instant TO = Instant.parse("2025-03-12T00:00:00Z");

  @Mock
  private AttentionRepository attentions;

  @Mock
  private AppliedDoseRepository doses;

  @Mock
  private UserRepository users;

  private StatisticsQueryService query;

  @BeforeEach
  void setUp() {
    query = new StatisticsQueryService(attentions, doses, users);
  }

  @Test
  void aggregatesRegisteredDosesAndExcludesCancelledOrOutOfRangeData() {
    AttentionEntity active = attention(ATTENTION_ID, PATIENT_ID, PROFESSIONAL_ID, FROM);
    active.complete(FROM);

    UUID cancelledAttentionId = UUID.fromString("55555555-5555-5555-5555-555555555555");
    AttentionEntity cancelled = attention(cancelledAttentionId, UUID.randomUUID(), UUID.randomUUID(), FROM);
    cancelled.cancel(FROM);

    AppliedDoseEntity fluDose = dose(ATTENTION_ID, Instant.parse("2025-03-10T10:00:00Z"), "Influenza", "FLU");
    AppliedDoseEntity mmrDose = dose(ATTENTION_ID, Instant.parse("2025-03-10T11:00:00Z"), "Triple viral", "MMR");
    AppliedDoseEntity cancelledDose = dose(ATTENTION_ID, Instant.parse("2025-03-10T12:00:00Z"), "Influenza", "FLU");
    cancelledDose.cancel("Correccion", PROFESSIONAL_ID, FROM);
    AppliedDoseEntity doseAtEnd = dose(ATTENTION_ID, TO, "Influenza", "FLU");
    when(attentions.findByInstitutionIdAndAttentionDateBetweenOrderByAttentionDateAsc(
        INSTITUTION_ID, FROM, TO)).thenReturn(List.of(active, cancelled));
    when(doses.findByAttentionIdInOrderByCreatedAtAsc(anyCollection()))
      .thenReturn(List.of(fluDose, mmrDose, cancelledDose, doseAtEnd));
    when(users.findByInstitutionIdAndIdIn(eq(INSTITUTION_ID), anyCollection())).thenReturn(List.<UserEntity>of());

    StatisticsDashboardResponse result = query.dashboard(INSTITUTION_ID, FROM, TO, "day");

    assertThat(result.kpis().dosesApplied()).isEqualTo(2);
    assertThat(result.kpis().uniquePatients()).isEqualTo(1);
    assertThat(result.kpis().activeVaccinators()).isEqualTo(1);
    assertThat(result.kpis().dosesPerPatient()).isEqualTo(2);
    assertThat(result.doseSeries()).hasSize(1);
    assertThat(result.doseSeries().get(0).label()).isEqualTo("2025-03-10");
    assertThat(result.doseSeries().get(0).uniquePatients()).isEqualTo(1);
    assertThat(result.vaccineDistribution()).hasSize(2);
    assertThat(result.vaccineDistribution())
        .extracting(StatisticsDashboardResponse.VaccineDistributionResponse::percentage)
        .containsExactlyInAnyOrder(50.0, 50.0);
    assertThat(result.vaccinatorProductivity()).singleElement().satisfies(productivity -> {
      assertThat(productivity.vaccinatorId()).isEqualTo(PROFESSIONAL_ID.toString());
      assertThat(productivity.doses()).isEqualTo(2);
      assertThat(productivity.uniquePatients()).isEqualTo(1);
    });

    verify(attentions).findByInstitutionIdAndAttentionDateBetweenOrderByAttentionDateAsc(
        INSTITUTION_ID, FROM, TO);
    verify(doses).findByAttentionIdInOrderByCreatedAtAsc(Set.of(ATTENTION_ID));
  }

  @Test
  void emptyPeriodReturnsZeroesAndDoesNotQueryDosesOrUsers() {
    when(attentions.findByInstitutionIdAndAttentionDateBetweenOrderByAttentionDateAsc(
        INSTITUTION_ID, FROM, TO)).thenReturn(List.of());

    StatisticsDashboardResponse result = query.dashboard(INSTITUTION_ID, FROM, TO, "unknown");

    assertThat(result.period().granularity()).isEqualTo("day");
    assertThat(result.kpis().dosesApplied()).isZero();
    assertThat(result.kpis().uniquePatients()).isZero();
    assertThat(result.kpis().activeVaccinators()).isZero();
    assertThat(result.doseSeries()).isEmpty();
    assertThat(result.vaccineDistribution()).isEmpty();
    assertThat(result.vaccinatorProductivity()).isEmpty();
    verifyNoInteractions(doses, users);
  }

  private AttentionEntity attention(UUID id, UUID patientId, UUID professionalId, Instant at) {
    return new AttentionEntity(id, patientId, professionalId, INSTITUTION_ID, at, null, null, at);
  }

  private AppliedDoseEntity dose(UUID attentionId, Instant at, String name, String code) {
    return AppliedDoseEntity.builder()
        .attentionId(attentionId)
        .applicationDate(at)
        .vaccine(UUID.randomUUID(), name, code, 1)
        .dose(null, "Primera", "1")
        .build();
  }
}