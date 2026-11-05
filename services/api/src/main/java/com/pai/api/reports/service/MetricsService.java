package com.pai.api.reports.service;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityPermissions;
import com.pai.api.identity.service.RoleCodes;
import com.pai.api.reports.dto.MetricsSummaryResponse;
import com.pai.api.reports.dto.RecentRecordResponse;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Metricas agregadas del home, acotadas a la institucion del actor (ADR-007).
 *
 * <p>Para administradores institucionales o superadministradores, muestra el
 * total consolidado del hospital. Para enfermeras y vacunadoras, muestra su
 * propio historial personal de atenciones y dosis en la institucion.
 *
 * <p>El calculo de los indicadores clinicos se delega en el puerto
 * {@link ClinicalMetricsQuery} (DIP): {@code reports} no conoce los repositorios
 * ni los enums del modulo {@code attentions}.
 */
@Service
public class MetricsService {

  private final ClinicalMetricsQuery metrics;
  private final DataScope dataScope;

  public MetricsService(ClinicalMetricsQuery metrics, DataScope dataScope) {
    this.metrics = metrics;
    this.dataScope = dataScope;
  }

  @Transactional(readOnly = true)
  public MetricsSummaryResponse summary(AuthorizedUser actor) {
    UUID institutionId = dataScope.institutionOf(actor);
    boolean isInstitutionalAdmin = isInstitutionalAdmin(actor);

    if (isInstitutionalAdmin) {
      return new MetricsSummaryResponse(
          metrics.patientsAttended(institutionId), metrics.dosesApplied(institutionId));
    }

    return new MetricsSummaryResponse(
        metrics.patientsAttendedByProfessional(institutionId, actor.getId()),
        metrics.dosesAppliedByProfessional(institutionId, actor.getId()));
  }

  @Transactional(readOnly = true)
  public List<RecentRecordResponse> recentRecords(AuthorizedUser actor, int limit) {
    if (isInstitutionalAdmin(actor)) {
      return List.of();
    }
    UUID institutionId = dataScope.institutionOf(actor);
    return metrics.recentRecords(institutionId, actor.getId(), false, limit);
  }

  private boolean isInstitutionalAdmin(AuthorizedUser actor) {
    return actor.hasPermission(IdentityPermissions.USER_MANAGE)
        || (actor.getRoles() != null
            && (actor.getRoles().contains(RoleCodes.ADMIN_INSTITUTION)
                || actor.getRoles().contains(RoleCodes.SUPER_ADMIN)));
  }
}
