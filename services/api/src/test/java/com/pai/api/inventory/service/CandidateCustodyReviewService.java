package com.pai.api.inventory.service;

import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.security.PermissionGuard;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;

/** Prototipo de lectura en src/test: no es bean, endpoint ni calculo de saldo. */
final class CandidateCustodyReviewService {
  private final JdbcTemplate db;
  private final PermissionGuard guard;
  private final DataScope scope;

  CandidateCustodyReviewService(JdbcTemplate db, PermissionGuard guard, DataScope scope) {
    this.db = db;
    this.guard = guard;
    this.scope = scope;
  }

  record Receipt(UUID id, UUID lotId, int vials, UUID receivedBy, Instant receivedAt, String note) {}
  record Event(UUID id, UUID lotId, int vials, String status, UUID reportedBy, Instant reportedAt,
      String note, UUID confirmedBy, Instant confirmedAt, String confirmationNote) {}
  record Regularization(UUID id, UUID resolutionId, int vials, UUID recordedBy, Instant recordedAt, String note) {}
  record Resolution(UUID id, UUID lotId, int vials, String kind, UUID recordedBy, Instant recordedAt,
      String note, List<Regularization> regularizations) {}
  record Finalization(UUID id, UUID lotId, String kind, UUID recordedBy, Instant recordedAt, String evidence) {}
  record Origin(UUID assignmentId, int dispatchedVials, int receivedVials, String status, UUID linkedBy, Instant linkedAt,
      List<Receipt> receipts, List<Event> events, List<Resolution> resolutions, List<Finalization> finalizations) {}
  record Review(UUID custodyId, UUID institutionId, UUID custodianId, UUID lotId, List<Origin> origins) {}
  private record Row(UUID custody, UUID custodian, UUID lot, UUID assignment, String kind,
      int sent, int received, String assignmentStatus, UUID evidenceId, UUID evidenceLot, int evidenceVials,
      String eventStatus, UUID actor1, Instant time1, String note1, UUID actor2, Instant time2, String note2,
      UUID parentResolution) {}
  private record ResolutionKey(UUID assignment, UUID resolution) {}

  @Transactional(readOnly = true)
  Review review(UUID actor, UUID institution, UUID custodyId) {
    UUID institutionId = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_READ"),
        Objects.requireNonNull(institution, "institution"));
    Objects.requireNonNull(custodyId, "custodyId");
    // Una sentencia evita multiplicar recibos por novedades y mantiene una vista por sentencia.
    var rows = db.query("""
        WITH selected AS (
          SELECT id, institution_id, lot_id, custodian_id
          FROM app.individual_custodies_candidate WHERE institution_id=? AND id=?
        ), evidence AS (
          SELECT o.custody_id, o.assignment_id, 'ORIGIN' AS kind, a.vial_count AS sent,
            a.received_vials AS received, a.status AS assignment_status,
            CAST(NULL AS UUID) AS evidence_id, CAST(NULL AS UUID) AS evidence_lot,
            CAST(NULL AS INTEGER) AS evidence_vials, CAST(NULL AS VARCHAR) AS event_status,
            o.linked_by AS actor1, o.linked_at AS time1,
            CAST(NULL AS VARCHAR) AS note1, CAST(NULL AS UUID) AS actor2,
            CAST(NULL AS TIMESTAMP WITH TIME ZONE) AS time2, CAST(NULL AS VARCHAR) AS note2,
            CAST(NULL AS UUID) AS parent_resolution
          FROM app.individual_custody_origins_candidate o
          JOIN selected s ON s.id=o.custody_id AND s.institution_id=o.institution_id
          JOIN app.inventory_assignments a ON a.id=o.assignment_id AND a.institution_id=o.institution_id
          UNION ALL
          SELECT o.custody_id, o.assignment_id, 'RECEIPT', 0, 0, CAST(NULL AS VARCHAR),
            r.id, r.lot_id, r.vials, CAST(NULL AS VARCHAR), r.received_by, r.received_at,
            r.difference_note, CAST(NULL AS UUID), CAST(NULL AS TIMESTAMP WITH TIME ZONE), CAST(NULL AS VARCHAR),
            CAST(NULL AS UUID)
          FROM app.individual_custody_origins_candidate o
          JOIN selected s ON s.id=o.custody_id AND s.institution_id=o.institution_id
          JOIN app.inventory_receipts r ON r.assignment_id=o.assignment_id AND r.institution_id=o.institution_id
          UNION ALL
          SELECT o.custody_id, o.assignment_id, 'EVENT', 0, 0, CAST(NULL AS VARCHAR),
            e.id, e.lot_id, e.vial_count, e.status, e.reported_by, e.reported_at, e.report_note,
            e.confirmed_by, e.confirmed_at, e.confirmation_note, CAST(NULL AS UUID)
          FROM app.individual_custody_origins_candidate o
          JOIN selected s ON s.id=o.custody_id AND s.institution_id=o.institution_id
          JOIN app.inventory_custody_events e ON e.assignment_id=o.assignment_id AND e.institution_id=o.institution_id
          UNION ALL
          SELECT o.custody_id, o.assignment_id, 'RESOLUTION', 0, 0, CAST(NULL AS VARCHAR),
            r.id, r.lot_id, r.vial_count, r.kind, r.recorded_by, r.recorded_at, r.note,
            CAST(NULL AS UUID), CAST(NULL AS TIMESTAMP WITH TIME ZONE), CAST(NULL AS VARCHAR), CAST(NULL AS UUID)
          FROM app.individual_custody_origins_candidate o
          JOIN selected s ON s.id=o.custody_id AND s.institution_id=o.institution_id
          JOIN app.inventory_difference_resolutions r ON r.assignment_id=o.assignment_id AND r.institution_id=o.institution_id
          UNION ALL
          SELECT o.custody_id, o.assignment_id, 'REGULARIZATION', 0, 0, CAST(NULL AS VARCHAR),
            g.id, r.lot_id, g.vial_count, CAST(NULL AS VARCHAR), g.recorded_by, g.recorded_at, g.note,
            CAST(NULL AS UUID), CAST(NULL AS TIMESTAMP WITH TIME ZONE), CAST(NULL AS VARCHAR), r.id
          FROM app.individual_custody_origins_candidate o
          JOIN selected s ON s.id=o.custody_id AND s.institution_id=o.institution_id
          JOIN app.inventory_difference_resolutions r ON r.assignment_id=o.assignment_id AND r.institution_id=o.institution_id
          JOIN app.inventory_depot_regularizations g ON g.resolution_id=r.id AND g.institution_id=r.institution_id
          UNION ALL
          SELECT o.custody_id, o.assignment_id, 'FINALIZATION', 0, 0, CAST(NULL AS VARCHAR),
            f.id, f.lot_id, CAST(NULL AS INTEGER), f.kind, f.recorded_by, f.recorded_at, f.evidence,
            CAST(NULL AS UUID), CAST(NULL AS TIMESTAMP WITH TIME ZONE), CAST(NULL AS VARCHAR), CAST(NULL AS UUID)
          FROM app.individual_custody_origins_candidate o
          JOIN selected s ON s.id=o.custody_id AND s.institution_id=o.institution_id
          JOIN app.transfer_finalizations_candidate f
            ON f.assignment_id=o.assignment_id AND f.institution_id=o.institution_id AND f.lot_id=o.lot_id
        )
        SELECT s.id AS custody_id, s.custodian_id, s.lot_id, e.*
        FROM selected s LEFT JOIN evidence e ON e.custody_id=s.id
        """,
        (rs, n) -> {
          var t1 = rs.getTimestamp("time1");
          var t2 = rs.getTimestamp("time2");
          return new Row(rs.getObject("custody_id", UUID.class), rs.getObject("custodian_id", UUID.class),
              rs.getObject("lot_id", UUID.class), rs.getObject("assignment_id", UUID.class), rs.getString("kind"),
              rs.getInt("sent"), rs.getInt("received"), rs.getString("assignment_status"),
              rs.getObject("evidence_id", UUID.class), rs.getObject("evidence_lot", UUID.class),
              rs.getInt("evidence_vials"), rs.getString("event_status"), rs.getObject("actor1", UUID.class),
              t1 == null ? null : t1.toInstant(), rs.getString("note1"), rs.getObject("actor2", UUID.class),
              t2 == null ? null : t2.toInstant(), rs.getString("note2"), rs.getObject("parent_resolution", UUID.class));
        }, institutionId, custodyId);
    if (rows.isEmpty()) throw new IllegalArgumentException("Custodia no encontrada.");
    var origins = new LinkedHashMap<UUID, Origin>();
    for (var row : rows) {
      if ("ORIGIN".equals(row.kind()))
        origins.put(row.assignment(), new Origin(row.assignment(), row.sent(), row.received(),
            row.assignmentStatus(), row.actor1(), row.time1(), new ArrayList<>(), new ArrayList<>(),
            new ArrayList<>(), new ArrayList<>()));
    }
    var resolutions = new LinkedHashMap<ResolutionKey, Resolution>();
    for (var row : rows) {
      if ("RECEIPT".equals(row.kind())) {
        var origin = Objects.requireNonNull(origins.get(row.assignment()));
        origin.receipts().add(new Receipt(row.evidenceId(), row.evidenceLot(), row.evidenceVials(),
            row.actor1(), row.time1(), row.note1()));
      } else if ("EVENT".equals(row.kind())) {
        var origin = Objects.requireNonNull(origins.get(row.assignment()));
        origin.events().add(new Event(row.evidenceId(), row.evidenceLot(), row.evidenceVials(),
            row.eventStatus(), row.actor1(), row.time1(), row.note1(), row.actor2(), row.time2(), row.note2()));
      } else if ("RESOLUTION".equals(row.kind())) {
        var origin = Objects.requireNonNull(origins.get(row.assignment()));
        var resolution = new Resolution(row.evidenceId(), row.evidenceLot(), row.evidenceVials(),
            row.eventStatus(), row.actor1(), row.time1(), row.note1(), new ArrayList<>());
        origin.resolutions().add(resolution);
        resolutions.put(new ResolutionKey(row.assignment(), row.evidenceId()), resolution);
      } else if ("FINALIZATION".equals(row.kind())) {
        var origin = Objects.requireNonNull(origins.get(row.assignment()));
        origin.finalizations().add(new Finalization(row.evidenceId(), row.evidenceLot(), row.eventStatus(),
            row.actor1(), row.time1(), row.note1()));
      }
    }
    for (var row : rows) {
      if ("REGULARIZATION".equals(row.kind())) {
        var resolution = Objects.requireNonNull(resolutions.get(new ResolutionKey(row.assignment(), row.parentResolution())));
        resolution.regularizations().add(new Regularization(row.evidenceId(), row.parentResolution(),
            row.evidenceVials(), row.actor1(), row.time1(), row.note1()));
      }
    }
    var result = origins.values().stream()
        .sorted(java.util.Comparator.comparing(Origin::assignmentId))
        .map(o -> new Origin(o.assignmentId(), o.dispatchedVials(), o.receivedVials(), o.status(), o.linkedBy(), o.linkedAt(),
            o.receipts().stream().sorted(java.util.Comparator.comparing(Receipt::receivedAt).thenComparing(Receipt::id)).toList(),
            o.events().stream().sorted(java.util.Comparator.comparing(Event::reportedAt).thenComparing(Event::id)).toList(),
            o.resolutions().stream().sorted(java.util.Comparator.comparing(Resolution::recordedAt).thenComparing(Resolution::id))
                .map(r -> new Resolution(r.id(), r.lotId(), r.vials(), r.kind(), r.recordedBy(), r.recordedAt(), r.note(),
                    r.regularizations().stream().sorted(java.util.Comparator.comparing(Regularization::recordedAt)
                        .thenComparing(Regularization::id)).toList())).toList(),
            o.finalizations().stream().sorted(java.util.Comparator.comparing(Finalization::recordedAt)
                .thenComparing(Finalization::id)).toList()))
        .toList();
    var selected = rows.getFirst();
    return new Review(selected.custody(), institutionId, selected.custodian(), selected.lot(), result);
  }
}
