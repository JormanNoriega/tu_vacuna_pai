package com.pai.api.reports.service;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.reports.domain.PatientIdentity;
import com.pai.api.reports.domain.RegistroDiarioDoseData;
import com.pai.api.reports.domain.RegistroDiarioRow;
import com.pai.api.reports.domain.ReportColumn;
import com.pai.api.reports.export.ExportedReport;
import com.pai.api.reports.export.PaiReportFactory;
import com.pai.api.reports.export.ReportFactoryProvider;
import com.pai.api.reports.export.ReportFormat;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * Client del patron Abstract Factory para el reporte "Registro Diario" PAI.
 *
 * <p>Obtiene las dosis via {@link RegistroDiarioQuery} (attentions) y la
 * identidad via {@link PatientIdentityQuery} (patients) —ambos puertos DIP—,
 * cruza los datos, elige la {@link PaiReportFactory} concreta segun el formato y
 * delega la escritura en la familia de productos. La institucion se deriva del
 * actor (ADR-007), nunca del cliente.
 */
@Service
public class RegistroDiarioExportService {

  private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("yyyy-MM-dd");
  private static final DateTimeFormatter DATE_TIME =
      DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm").withZone(ZoneOffset.UTC);

  /** Orden y titulos de las columnas del reporte (una fila por dosis aplicada). */
  private static final List<ReportColumn> COLUMNS =
      List.of(
          new ReportColumn("Consecutivo", row -> text(row.consecutive())),
          new ReportColumn("Fecha de atencion", row -> dateTime(row.attentionDate())),
          new ReportColumn("Tipo de identificacion", RegistroDiarioRow::documentType),
          new ReportColumn("Numero de identificacion", RegistroDiarioRow::documentNumber),
          new ReportColumn("Primer nombre", RegistroDiarioRow::firstName),
          new ReportColumn("Segundo nombre", RegistroDiarioRow::secondName),
          new ReportColumn("Primer apellido", RegistroDiarioRow::lastName),
          new ReportColumn("Segundo apellido", RegistroDiarioRow::secondLastName),
          new ReportColumn("Fecha de nacimiento", row -> date(row.birthDate())),
          new ReportColumn("Sexo", RegistroDiarioRow::sex),
          new ReportColumn("Vacuna", RegistroDiarioRow::vaccineName),
          new ReportColumn("Codigo", RegistroDiarioRow::vaccineCode),
          new ReportColumn("Dosis", RegistroDiarioRow::doseLabel),
          new ReportColumn("Lote", RegistroDiarioRow::lotNumber),
          new ReportColumn("Laboratorio", RegistroDiarioRow::laboratory),
          new ReportColumn("Jeringa", RegistroDiarioRow::syringe),
          new ReportColumn("Gotero", RegistroDiarioRow::dropper),
          new ReportColumn("Observacion", RegistroDiarioRow::observation),
          new ReportColumn("Fecha de aplicacion", row -> dateTime(row.applicationDate())),
          new ReportColumn("Estado", RegistroDiarioRow::status));

  private final RegistroDiarioQuery registroDiarioQuery;
  private final PatientIdentityQuery patientIdentityQuery;
  private final ReportFactoryProvider factoryProvider;
  private final DataScope dataScope;

  public RegistroDiarioExportService(
      RegistroDiarioQuery registroDiarioQuery,
      PatientIdentityQuery patientIdentityQuery,
      ReportFactoryProvider factoryProvider,
      DataScope dataScope) {
    this.registroDiarioQuery = registroDiarioQuery;
    this.patientIdentityQuery = patientIdentityQuery;
    this.factoryProvider = factoryProvider;
    this.dataScope = dataScope;
  }

  public ExportedReport export(
      AuthorizedUser actor, Instant from, Instant to, ReportFormat format) {
    UUID institutionId = dataScope.resolveInstitutionId(actor, actor.getInstitution().getId());
    List<RegistroDiarioRow> rows = buildRows(institutionId, from, to);

    PaiReportFactory factory = factoryProvider.create(format);
    factory.headerBuilder().writeHeader(COLUMNS.stream().map(ReportColumn::title).toList());
    for (RegistroDiarioRow row : rows) {
      factory
          .rowWriter()
          .writeRow(COLUMNS.stream().map(column -> column.value().apply(row)).toList());
    }
    byte[] content = factory.exporter().export();

    return new ExportedReport(
        content, filename(institutionId, from, format), format.contentType());
  }

  private List<RegistroDiarioRow> buildRows(UUID institutionId, Instant from, Instant to) {
    List<RegistroDiarioDoseData> doseRows = registroDiarioQuery.doses(institutionId, from, to);
    if (doseRows.isEmpty()) {
      return List.of();
    }

    Set<UUID> patientIds =
        doseRows.stream().map(RegistroDiarioDoseData::patientId).collect(Collectors.toSet());
    Map<UUID, PatientIdentity> patientById =
        patientIdentityQuery.byIds(patientIds).stream()
            .collect(Collectors.toMap(PatientIdentity::id, identity -> identity));

    List<RegistroDiarioRow> rows = new ArrayList<>();
    for (RegistroDiarioDoseData dose : doseRows) {
      PatientIdentity patient = patientById.get(dose.patientId());
      if (patient == null) {
        continue;
      }
      rows.add(
          new RegistroDiarioRow(
              dose.consecutive(),
              dose.attentionDate(),
              patient.documentType(),
              patient.documentNumber(),
              patient.firstName(),
              patient.secondName(),
              patient.lastName(),
              patient.secondLastName(),
              patient.birthDate(),
              patient.sex(),
              dose.vaccineName(),
              dose.vaccineCode(),
              dose.doseLabel(),
              dose.lotNumber(),
              dose.laboratory(),
              dose.syringe(),
              dose.dropper(),
              dose.observation(),
              dose.applicationDate(),
              dose.status()));
    }
    return rows;
  }

  private static String filename(UUID institutionId, Instant from, ReportFormat format) {
    return "registro-diario-" + institutionId + "-" + fileDate(from) + "." + format.extension();
  }

  private static String text(Object value) {
    return value == null ? "" : value.toString();
  }

  private static String date(LocalDate value) {
    return value == null ? "" : DATE.format(value);
  }

  private static String dateTime(Instant value) {
    return value == null ? "" : DATE_TIME.format(value);
  }

  private static String fileDate(Instant value) {
    return value == null ? "sin-fecha" : DATE.format(value.atZone(ZoneOffset.UTC).toLocalDate());
  }
}
