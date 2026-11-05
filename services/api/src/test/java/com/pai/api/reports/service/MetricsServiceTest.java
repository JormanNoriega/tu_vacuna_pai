package com.pai.api.reports.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityPermissions;
import com.pai.api.identity.service.RoleCodes;
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
  private ClinicalMetricsQuery metrics;

  @Mock
  private DataScope dataScope;

  private MetricsService service;

  @BeforeEach
  void setUp() {
    service = new MetricsService(metrics, dataScope);
  }

  @Test
  void resume_pacientes_y_dosis_del_profesional_para_vacunadoras() {
    AuthorizedUser vaccinator = vaccinatorActor();
    when(dataScope.institutionOf(vaccinator)).thenReturn(INSTITUTION_ID);
    when(metrics.patientsAttendedByProfessional(INSTITUTION_ID, ACTOR_ID)).thenReturn(5L);
    when(metrics.dosesAppliedByProfessional(INSTITUTION_ID, ACTOR_ID)).thenReturn(8L);

    MetricsSummaryResponse summary = service.summary(vaccinator);

    assertThat(summary.patientsAttended()).isEqualTo(5L);
    assertThat(summary.dosesApplied()).isEqualTo(8L);
  }

  @Test
  void resume_pacientes_y_dosis_institucionales_para_administradores() {
    AuthorizedUser admin = adminActor();
    when(dataScope.institutionOf(admin)).thenReturn(INSTITUTION_ID);
    when(metrics.patientsAttended(INSTITUTION_ID)).thenReturn(120L);
    when(metrics.dosesApplied(INSTITUTION_ID)).thenReturn(340L);

    MetricsSummaryResponse summary = service.summary(admin);

    assertThat(summary.patientsAttended()).isEqualTo(120L);
    assertThat(summary.dosesApplied()).isEqualTo(340L);
  }

  @Test
  void recentRecords_retorna_registros_del_profesional_para_vacunadoras() {
    AuthorizedUser vaccinator = vaccinatorActor();
    when(dataScope.institutionOf(vaccinator)).thenReturn(INSTITUTION_ID);
    com.pai.api.reports.dto.RecentRecordResponse record =
        new com.pai.api.reports.dto.RecentRecordResponse(
            UUID.randomUUID(), UUID.randomUUID(), "Paciente Juan", "COVID-19", Instant.now());
    when(metrics.recentRecords(INSTITUTION_ID, ACTOR_ID, false, 5)).thenReturn(List.of(record));

    List<com.pai.api.reports.dto.RecentRecordResponse> records =
        service.recentRecords(vaccinator, 5);

    assertThat(records).containsExactly(record);
  }

  @Test
  void recentRecords_retorna_lista_vacia_para_administradores() {
    AuthorizedUser admin = adminActor();

    List<com.pai.api.reports.dto.RecentRecordResponse> records = service.recentRecords(admin, 5);

    assertThat(records).isEmpty();
  }

  private AuthorizedUser vaccinatorActor() {
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
        List.of(RoleCodes.VACCINATOR),
        List.of("ATTENTION_READ", "USER_WRITE_VACCINATION"),
        Instant.now());
  }

  private AuthorizedUser adminActor() {
    return new AuthorizedUser(
        UUID.fromString("33333333-3333-3333-3333-333333333333"),
        "admin@hosp.a",
        "Carlos Admin",
        new InstitutionEntity(
            INSTITUTION_ID,
            "HOSP-A",
            "Hospital A",
            InstitutionEntity.Status.ACTIVE,
            (short) 72,
            Instant.now(),
            Instant.now()),
        List.of(RoleCodes.ADMIN_INSTITUTION),
        List.of("ATTENTION_READ", IdentityPermissions.USER_MANAGE),
        Instant.now());
  }
}
