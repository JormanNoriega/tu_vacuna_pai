package com.pai.api.inventory.service;

import com.pai.api.identity.service.DataScope;
import com.pai.api.inventory.domain.VialTransfer;
import com.pai.api.inventory.domain.PartialReceipt;
import com.pai.api.inventory.domain.HistoricalCustodyTransition;
import com.pai.api.shared.security.PermissionGuard;
import java.time.Instant;
import java.time.LocalDate;
import java.time.Clock;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Isolation;

/** Operaciones online iniciales. No reserva cuotas offline ni consume dosis clinicas. */
@Service
public class InventoryService {
  private final JdbcTemplate db;
  private final PermissionGuard guard;
  private final DataScope scope;
  private final Clock clock;
  private ApplicationEventPublisher events = event -> {};
  private static final ZoneId OPERATIONAL_ZONE = ZoneId.of("America/Bogota");

  @Autowired
  public InventoryService(JdbcTemplate db, PermissionGuard guard, DataScope scope) {
    this(db, guard, scope, Clock.systemUTC());
  }

  InventoryService(JdbcTemplate db, PermissionGuard guard, DataScope scope, Clock clock) {
    this.db = db;
    this.guard = guard;
    this.scope = scope;
    this.clock = clock;
  }

  public record Lot(UUID id, UUID vaccineId, String vaccineName, String manufacturer, String lotNumber,
      LocalDate expiresOn, int dosesPerVial, int availableVials) {}

  public record AssignmentView(UUID id, UUID lotId, UUID vaccinatorId, int vialCount,
      String status, Instant dispatchedAt, String lotNumber, String vaccineName, UUID campaignId, String campaignName,
      int receivedVials, int resolvedVials, String differenceNote) {}

  public record MovementView(UUID id, String vaccineName, String lotNumber, String kind,
      int vialCount, Instant occurredAt, String note) {}

  /** Cantidades registradas para seguimiento, no saldos ni dictamen sanitario. */
  public record PendingFollowUp(UUID id, UUID assignmentId, UUID lotId, String vaccineName,
      String lotNumber, String kind, int originalVials, long regularizedVials,
      long pendingVials, UUID recordedBy, Instant recordedAt, String note) {}

  @Transactional(readOnly = true)
  public List<PendingFollowUp> listPendingFollowUps(UUID actor, UUID institution) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_READ");
    return db.query("""
        SELECT p.id, p.assignment_id, p.lot_id, v.name AS vaccine_name, l.lot_number,
          p.kind, p.original_vials, p.regularized_vials,
          p.original_vials - p.regularized_vials AS pending_vials,
          p.recorded_by, p.recorded_at, p.note
        FROM (
          SELECT r.id, r.institution_id, r.assignment_id, r.lot_id, 'DISPATCH_CORRECTION' AS kind,
            r.vial_count AS original_vials,
            (SELECT COALESCE(SUM(g.vial_count), 0) FROM app.inventory_depot_regularizations g
             WHERE g.institution_id=r.institution_id AND g.resolution_id=r.id) AS regularized_vials,
            r.recorded_by, r.recorded_at, r.note
          FROM app.inventory_difference_resolutions r
          WHERE r.institution_id=? AND r.kind='DISPATCH_CORRECTION'
          UNION ALL
          SELECT e.id, e.institution_id, e.assignment_id, e.lot_id, 'RETURN_PENDING',
            e.vial_count, CAST(0 AS BIGINT), e.reported_by, e.reported_at, e.report_note
          FROM app.inventory_custody_events e
          WHERE e.institution_id=? AND e.status='RETURN_PENDING'
        ) p
        JOIN app.inventory_lots l ON l.id=p.lot_id AND l.institution_id=p.institution_id
        JOIN app.vaccines v ON v.id=l.vaccine_id
        WHERE p.regularized_vials < p.original_vials
        ORDER BY p.recorded_at, p.id
        """,
        (rs, n) -> new PendingFollowUp(rs.getObject("id", UUID.class), rs.getObject("assignment_id", UUID.class),
            rs.getObject("lot_id", UUID.class), rs.getString("vaccine_name"), rs.getString("lot_number"),
            rs.getString("kind"), rs.getInt("original_vials"), rs.getLong("regularized_vials"),
            rs.getLong("pending_vials"), rs.getObject("recorded_by", UUID.class),
            rs.getTimestamp("recorded_at").toInstant(), rs.getString("note")), institutionId, institutionId);
  }

  /** Resolución con sus regularizaciones, sin inferir ubicación ni saldo. */
  public record ConciliationResolution(UUID id, String kind, int vialCount, long regularizedVials,
      long pendingVials, String note, UUID recordedBy, Instant recordedAt) {}
  /** Devolución declarada pero aún no confirmada físicamente. */
  public record PendingReturn(UUID id, int vialCount, UUID reportedBy, Instant reportedAt, String note) {}
  /**
   * Estado registrado para conciliación administrativa.
   * No es un saldo físico, una disponibilidad sanitaria ni una certificación de custodia.
   */
  public record DeliveryConciliation(UUID assignmentId, UUID lotId, UUID custodianId,
      String vaccineName, String lotNumber, String status, int dispatchedVials, int receivedVials,
      int resolvedVials, long pendingDifferenceVials, long lostVials, long dispatchCorrectedVials,
      long regularizedVials, long pendingVerificationVials, long pendingReturnVials,
      long receiptCount, boolean assignmentOnlyReceiptEvidence,
      List<ConciliationResolution> resolutions, List<PendingReturn> pendingReturns,
      java.util.Set<String> reviewReasons) {}

  /**
   * Reúne cantidades y referencias registradas para revisión administrativa.
   * No calcula existencia física, no modifica datos y no asigna devoluciones a recepciones.
   */
  @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
  public DeliveryConciliation reviewConciliation(UUID actor, UUID institution, UUID assignmentId) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_READ");
    Objects.requireNonNull(assignmentId, "assignmentId");
    var assignments = db.query("""
        SELECT a.lot_id, a.vaccinator_id, a.vial_count, a.received_vials, a.resolved_vials,
          a.status, l.lot_number, v.name AS vaccine_name
        FROM app.inventory_assignments a
        JOIN app.inventory_lots l ON l.id=a.lot_id AND l.institution_id=a.institution_id
        JOIN app.vaccines v ON v.id=l.vaccine_id
        WHERE a.institution_id=? AND a.id=?
        """,
        (rs, n) -> new ConciliationAssignment(rs.getObject("lot_id", UUID.class),
            rs.getObject("vaccinator_id", UUID.class), rs.getInt("vial_count"),
            rs.getInt("received_vials"), rs.getInt("resolved_vials"), rs.getString("status"),
            rs.getString("vaccine_name"), rs.getString("lot_number")), institutionId, assignmentId);
    if (assignments.isEmpty()) throw new IllegalArgumentException("Entrega no encontrada en la institucion.");
    var assignment = assignments.getFirst();
    var receiptTotals = db.queryForObject("SELECT COUNT(*) AS receipt_count, "
            + "COALESCE(SUM(vials), 0) AS receipt_vials FROM app.inventory_receipts "
            + "WHERE institution_id=? AND assignment_id=?",
        (rs, n) -> new ReceiptTotals(rs.getLong("receipt_count"), rs.getLong("receipt_vials")),
        institutionId, assignmentId);
    long receiptCount = receiptTotals == null ? 0 : receiptTotals.count();
    long receiptVials = receiptTotals == null ? 0 : receiptTotals.vials();
    var resolutions = db.query("SELECT r.id, r.kind, r.vial_count, r.note, r.recorded_by, r.recorded_at, "
            + "COALESCE((SELECT SUM(g.vial_count) FROM app.inventory_depot_regularizations g "
            + "WHERE g.institution_id=r.institution_id AND g.resolution_id=r.id), 0) AS regularized_vials "
            + "FROM app.inventory_difference_resolutions r WHERE r.institution_id=? AND r.assignment_id=? "
            + "ORDER BY r.recorded_at, r.id",
        (rs, n) -> {
          int vials = rs.getInt("vial_count");
          long regularized = rs.getLong("regularized_vials");
          return new ConciliationResolution(rs.getObject("id", UUID.class), rs.getString("kind"), vials,
              regularized, Math.max(0L, vials - regularized), rs.getString("note"),
              rs.getObject("recorded_by", UUID.class), rs.getTimestamp("recorded_at").toInstant());
        }, institutionId, assignmentId);
    var pendingReturns = db.query("SELECT id, vial_count, reported_by, reported_at, report_note "
            + "FROM app.inventory_custody_events WHERE institution_id=? AND assignment_id=? "
            + "AND status='RETURN_PENDING' ORDER BY reported_at, id",
        (rs, n) -> new PendingReturn(rs.getObject("id", UUID.class), rs.getInt("vial_count"),
            rs.getObject("reported_by", UUID.class), rs.getTimestamp("reported_at").toInstant(),
            rs.getString("report_note")), institutionId, assignmentId);
    long lost = resolutions.stream().filter(r -> "LOST".equals(r.kind()))
        .mapToLong(ConciliationResolution::vialCount).sum();
    long corrected = resolutions.stream().filter(r -> "DISPATCH_CORRECTION".equals(r.kind()))
        .mapToLong(ConciliationResolution::vialCount).sum();
    long regularized = resolutions.stream().filter(r -> "DISPATCH_CORRECTION".equals(r.kind()))
        .mapToLong(ConciliationResolution::regularizedVials).sum();
    long pendingVerification = resolutions.stream().filter(r -> "DISPATCH_CORRECTION".equals(r.kind()))
        .mapToLong(ConciliationResolution::pendingVials).sum();
    long pendingReturnVials = pendingReturns.stream().mapToLong(PendingReturn::vialCount).sum();
    long pendingDifference = (long) assignment.dispatched() - assignment.received() - assignment.resolved();
    boolean assignmentOnly = receiptCount == 0 && assignment.received() > 0
        && "RECEIVED".equals(assignment.status()) && assignment.resolved() == 0
        && assignment.received() == assignment.dispatched();
    var reasons = new java.util.TreeSet<String>();
    if (pendingDifference < 0) reasons.add("NEGATIVE_PENDING_DIFFERENCE");
    if (receiptCount > 0 && receiptVials != assignment.received()) reasons.add("RECEIPT_TOTAL_MISMATCH");
    long resolutionTotal = resolutions.stream().mapToLong(ConciliationResolution::vialCount).sum();
    if (resolutionTotal != assignment.resolved()) reasons.add("RESOLUTION_TOTAL_MISMATCH");
    if (resolutions.stream().anyMatch(r -> !"LOST".equals(r.kind())
        && !"DISPATCH_CORRECTION".equals(r.kind()))) reasons.add("UNKNOWN_RESOLUTION_KIND");
    if (resolutions.stream().anyMatch(r -> r.regularizedVials() > r.vialCount()))
      reasons.add("REGULARIZATION_EXCEEDS_RESOLUTION");
    boolean pending = pendingDifference > 0;
    if ((("RECEIVED".equals(assignment.status()) || "CLOSED_WITH_DIFFERENCE".equals(assignment.status()))
        && pending) || ("PARTIALLY_RECEIVED".equals(assignment.status()) && !pending))
      reasons.add("STATUS_PENDING_MISMATCH");
    return new DeliveryConciliation(assignmentId, assignment.lot(), assignment.custodian(),
        assignment.vaccineName(), assignment.lotNumber(), assignment.status(), assignment.dispatched(),
        assignment.received(), assignment.resolved(), pendingDifference, lost, corrected, regularized,
        pendingVerification, pendingReturnVials, receiptCount, assignmentOnly,
        List.copyOf(resolutions), List.copyOf(pendingReturns), java.util.Collections.unmodifiableSet(reasons));
  }

  private record ConciliationAssignment(UUID lot, UUID custodian, int dispatched, int received,
      int resolved, String status, String vaccineName, String lotNumber) {}
  private record ReceiptTotals(long count, long vials) {}

  @Transactional(readOnly = true)
  public List<MovementView> listMovements(UUID actor, UUID institution) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_READ");
    return db.query("SELECT m.id, v.name, l.lot_number, m.kind, m.vial_count, m.occurred_at, m.note "
            + "FROM app.inventory_movements m JOIN app.inventory_lots l ON l.id = m.lot_id "
            + "AND l.institution_id = m.institution_id JOIN app.vaccines v ON v.id = l.vaccine_id "
            + "WHERE m.institution_id = ? ORDER BY m.occurred_at DESC, m.id",
        (rs, n) -> new MovementView(rs.getObject("id", UUID.class), rs.getString("name"),
            rs.getString("lot_number"), rs.getString("kind"), rs.getInt("vial_count"),
            rs.getTimestamp("occurred_at").toInstant(), rs.getString("note")), institutionId);
  }

  /** El lote y su entrada inicial se confirman o se revierten juntos. */
  @Transactional
  public UUID createLotWithEntry(UUID actor, UUID institution, UUID id, UUID vaccineId,
      String manufacturer, String lotNumber, LocalDate expiresOn, int dosesPerVial,
      UUID movementId, int vials, Instant occurredAt, String note) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_WRITE");
    Objects.requireNonNull(movementId, "movementId");
    positive(vials);
    Objects.requireNonNull(occurredAt, "occurredAt");
    String reason = requiredText(note);
    lockInstitution(institutionId);
    boolean exists = validateOrInsertLot(actor, institutionId, id, vaccineId, manufacturer,
        lotNumber, expiresOn, dosesPerVial);
    if (exists) {
      requireLotCreation(institutionId, id, actor, "LOT_WITH_ENTRY", movementId);
      var movement = findMovement(institutionId, movementId);
      if (movement == null) throw new IllegalStateException("La entrada inicial no está registrada.");
      checkMovement(movement, "ENTRY", id, null, vials, occurredAt, actor, reason);
      return id;
    }
    recordEntry(actor, institution, movementId, id, vials, occurredAt, note);
    db.update("INSERT INTO app.inventory_lot_creation_operations (lot_id, institution_id, kind, movement_id, created_by) "
        + "VALUES (?, ?, 'LOT_WITH_ENTRY', ?, ?)", id, institutionId, movementId, actor);
    return id;
  }

  private UUID authorize(UUID actor, UUID institution, String permission) {
    Objects.requireNonNull(institution, "institution");
    return scope.resolveInstitutionId(guard.require(actor, permission), institution);
  }

  @Transactional
  public UUID createLot(UUID actor, UUID institution, UUID id, UUID vaccineId,
      String manufacturer, String lotNumber, LocalDate expiresOn, int dosesPerVial) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_WRITE");
    lockInstitution(institutionId);
    boolean exists = validateOrInsertLot(actor, institutionId, id, vaccineId, manufacturer,
        lotNumber, expiresOn, dosesPerVial);
    if (exists) {
      requireLotCreation(institutionId, id, actor, "LOT_ONLY", null);
    } else {
      db.update("INSERT INTO app.inventory_lot_creation_operations (lot_id, institution_id, kind, created_by) "
          + "VALUES (?, ?, 'LOT_ONLY', ?)", id, institutionId, actor);
    }
    return id;
  }

  private void lockInstitution(UUID institutionId) {
    var rows = db.query("SELECT id FROM app.institutions WHERE id = ? FOR UPDATE",
        (rs, n) -> rs.getObject("id", UUID.class), institutionId);
    if (rows.isEmpty()) throw new IllegalArgumentException("Institucion no encontrada.");
  }

  /** El bloqueo institucional serializa nuevas creaciones y sus reintentos. */
  private boolean validateOrInsertLot(UUID actor, UUID institutionId, UUID id, UUID vaccineId,
      String manufacturer, String lotNumber, LocalDate expiresOn, int dosesPerVial) {
    Objects.requireNonNull(id, "id");
    Objects.requireNonNull(vaccineId, "vaccineId");
    Objects.requireNonNull(expiresOn, "expiresOn");
    String maker = requiredText(manufacturer);
    String number = requiredText(lotNumber);
    if (dosesPerVial <= 0) throw new IllegalArgumentException("La capacidad debe ser positiva.");
    var existing = db.query("SELECT vaccine_id, manufacturer, lot_number, expires_on, doses_per_vial, created_by "
            + "FROM app.inventory_lots WHERE institution_id = ? AND id = ?",
        (rs, n) -> new StoredLot(rs.getObject("vaccine_id", UUID.class), rs.getString("manufacturer"),
            rs.getString("lot_number"), rs.getObject("expires_on", LocalDate.class),
            rs.getInt("doses_per_vial"), rs.getObject("created_by", UUID.class)), institutionId, id);
    if (!existing.isEmpty()) {
      var lot = existing.getFirst();
      if (!Objects.equals(lot.vaccineId(), vaccineId) || !lot.manufacturer().equals(maker)
          || !lot.lotNumber().equals(number) || !lot.expiresOn().equals(expiresOn)
          || lot.dosesPerVial() != dosesPerVial || !Objects.equals(lot.actor(), actor))
        throw new IllegalArgumentException("Identificador de lote usado con datos diferentes.");
      return true;
    }
    db.update("INSERT INTO app.inventory_lots (id, institution_id, vaccine_id, manufacturer, "
        + "lot_number, expires_on, doses_per_vial, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        id, institutionId, vaccineId, maker, number, expiresOn, dosesPerVial, actor);
    return false;
  }

  private record StoredLot(UUID vaccineId, String manufacturer, String lotNumber,
      LocalDate expiresOn, int dosesPerVial, UUID actor) {}

  private void requireLotCreation(UUID institution, UUID lot, UUID actor, String kind, UUID movement) {
    var rows = db.query("SELECT kind, movement_id, created_by FROM app.inventory_lot_creation_operations "
            + "WHERE institution_id = ? AND lot_id = ?",
        (rs, n) -> new LotCreation(rs.getString("kind"), rs.getObject("movement_id", UUID.class),
            rs.getObject("created_by", UUID.class)), institution, lot);
    if (rows.isEmpty() || !rows.getFirst().kind().equals(kind)
        || !Objects.equals(rows.getFirst().movement(), movement) || !Objects.equals(rows.getFirst().actor(), actor))
      throw new IllegalArgumentException("No se puede verificar el reintento de creación del lote.");
  }

  private record LotCreation(String kind, UUID movement, UUID actor) {}

  @Transactional(readOnly = true)
  public List<Lot> listLots(UUID actor, UUID institution) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_READ");
    return db.query("SELECT l.id, l.vaccine_id, v.name AS vaccine_name, l.manufacturer, l.lot_number, "
            + "l.expires_on, l.doses_per_vial, l.available_vials FROM app.inventory_lots l "
            + "JOIN app.vaccines v ON v.id = l.vaccine_id WHERE l.institution_id = ? ORDER BY l.expires_on, l.id",
        (rs, n) -> new Lot(rs.getObject("id", UUID.class), rs.getObject("vaccine_id", UUID.class),
            rs.getString("vaccine_name"), rs.getString("manufacturer"), rs.getString("lot_number"),
            rs.getObject("expires_on", LocalDate.class), rs.getInt("doses_per_vial"),
            rs.getInt("available_vials")), institutionId);
  }

  @Transactional(readOnly = true)
  public List<AssignmentView> listAssignments(UUID actor, UUID institution) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_READ");
    return db.query(assignmentQuery() + " WHERE a.institution_id = ? ORDER BY a.dispatched_at DESC, a.id",
        (rs, n) -> new AssignmentView(rs.getObject("id", UUID.class),
            rs.getObject("lot_id", UUID.class), rs.getObject("vaccinator_id", UUID.class),
            rs.getInt("vial_count"), rs.getString("status"), rs.getTimestamp("dispatched_at").toInstant(),
            rs.getString("lot_number"), rs.getString("vaccine_name"), rs.getObject("campaign_id", UUID.class), rs.getString("campaign_name"),
            rs.getInt("received_vials"), rs.getInt("resolved_vials"), rs.getString("difference_note")),
        institutionId);
  }

  /** El vacunador solo puede consultar sus propias entregas. */
  @Transactional(readOnly = true)
  public List<AssignmentView> listMyAssignments(UUID actor, UUID institution) {
    UUID institutionId = authorize(actor, institution, "ATTENTION_CREATE");
    return db.query(assignmentQuery() + " WHERE a.institution_id = ? AND a.vaccinator_id = ? "
            + "ORDER BY a.dispatched_at DESC, a.id",
        (rs, n) -> new AssignmentView(rs.getObject("id", UUID.class),
            rs.getObject("lot_id", UUID.class), rs.getObject("vaccinator_id", UUID.class),
            rs.getInt("vial_count"), rs.getString("status"), rs.getTimestamp("dispatched_at").toInstant(),
            rs.getString("lot_number"), rs.getString("vaccine_name"), rs.getObject("campaign_id", UUID.class), rs.getString("campaign_name"),
            rs.getInt("received_vials"), rs.getInt("resolved_vials"), rs.getString("difference_note")),
        institutionId, actor);
  }

  private String assignmentQuery() {
    return "SELECT a.id, a.lot_id, a.vaccinator_id, a.vial_count, a.received_vials, a.resolved_vials, a.status, a.dispatched_at, a.campaign_id, "
        + "(SELECT r.difference_note FROM app.inventory_receipts r WHERE r.institution_id = a.institution_id "
        + "AND r.assignment_id = a.id AND r.difference_note <> '' ORDER BY r.received_at DESC, r.id DESC LIMIT 1) AS difference_note, "
        + "l.lot_number, v.name AS vaccine_name, c.name AS campaign_name FROM app.inventory_assignments a "
        + "JOIN app.inventory_lots l ON l.id = a.lot_id AND l.institution_id = a.institution_id "
        + "JOIN app.vaccines v ON v.id = l.vaccine_id "
        + "LEFT JOIN app.inventory_campaigns c ON c.id = a.campaign_id AND c.institution_id = a.institution_id";
  }

  @Autowired
  void setEvents(ApplicationEventPublisher events) { this.events = events; }

  public record ReceivedLot(UUID lotId, String lotNumber, LocalDate expiresOn) {}

  /**
   * Evidencia de recepción, no saldo clínico. Una recepción previa no prueba
   * que aún queden dosis utilizables ni que se disponga de los insumos.
   */
  @Transactional(readOnly = true)
  public List<ReceivedLot> listMyReceivedLots(UUID actor, UUID institution, UUID vaccineId) {
    return listMyReceivedLots(actor, institution, vaccineId, false);
  }

  /**
   * Descarta entregas sin frascos sin comprometer en los registros logísticos.
   * No acredita existencias físicas ni descuenta consumos clínicos históricos.
   */
  @Transactional(readOnly = true)
  public List<ReceivedLot> listMyUncommittedReceivedLots(
      UUID actor, UUID institution, UUID vaccineId) {
    return listMyReceivedLots(actor, institution, vaccineId, true);
  }

  private List<ReceivedLot> listMyReceivedLots(
      UUID actor, UUID institution, UUID vaccineId, boolean requireUncommitted) {
    UUID institutionId = authorize(actor, institution, "ATTENTION_CREATE");
    LocalDate today = LocalDate.now(clock.withZone(OPERATIONAL_ZONE));
    return db.query("""
        SELECT l.id, l.lot_number, l.expires_on
        FROM app.inventory_lots l
        WHERE l.institution_id = ? AND l.vaccine_id = ? AND l.expires_on >= ?
          AND EXISTS (
            SELECT 1 FROM app.inventory_assignments a
            WHERE a.institution_id = l.institution_id AND a.lot_id = l.id
              AND a.vaccinator_id = ? AND a.received_vials > 0
              AND a.status IN ('RECEIVED', 'PARTIALLY_RECEIVED', 'CLOSED_WITH_DIFFERENCE')
              AND (NOT ? OR a.received_vials >
                COALESCE((SELECT SUM(e.vial_count) FROM app.inventory_custody_events e
                  WHERE e.institution_id = a.institution_id AND e.lot_id = a.lot_id
                    AND e.assignment_id = a.id), 0) +
                COALESCE((SELECT SUM(r.vial_count) FROM app.inventory_installation_reservations r
                  WHERE r.institution_id = a.institution_id AND r.lot_id = a.lot_id
                    AND r.assignment_id = a.id AND r.vaccinator_id = a.vaccinator_id), 0))
          )
        ORDER BY l.expires_on, l.id
        """, (rs, n) -> new ReceivedLot(rs.getObject("id", UUID.class),
            rs.getString("lot_number"), rs.getObject("expires_on", LocalDate.class)),
        institutionId, vaccineId, today, actor, requireUncommitted);
  }

  public record HistoricalReceipt(UUID id, UUID assignmentId, UUID lotId, int vials,
      UUID receivedBy, Instant receivedAt, String differenceNote) {}
  public record HistoricalEvent(UUID id, UUID assignmentId, UUID lotId, int vials, String status,
      UUID reportedBy, Instant reportedAt, String reportNote, UUID confirmedBy,
      Instant confirmedAt, String confirmationNote) {}
  public record HistoricalReview(UUID assignmentId, UUID lotId, UUID custodianId, int dispatchedVials,
      int receivedVials, int resolvedVials, String status, boolean assignmentOnlyReceiptEvidence,
      List<HistoricalReceipt> receipts, List<HistoricalEvent> events, java.util.Set<String> reviewReasons) {}

  /**
   * Revisión informativa: no calcula saldo ni altera el historial.
   * Una sola sentencia obtiene entrega, recepciones y novedades sin lectura mezclada.
   */
  @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
  public HistoricalReview reviewHistoricalCustody(UUID actor, UUID institution, UUID assignmentId) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_READ");
    Objects.requireNonNull(assignmentId, "assignmentId");
    var rows = db.query("""
        WITH selected AS (
          SELECT id, institution_id, lot_id, vaccinator_id, vial_count, received_vials, resolved_vials, status
          FROM app.inventory_assignments WHERE institution_id = ? AND id = ?
        ), evidence AS (
          SELECT 'ASSIGNMENT' AS evidence_kind, CAST(NULL AS UUID) AS evidence_id,
            CAST(NULL AS UUID) AS evidence_lot, CAST(NULL AS INTEGER) AS evidence_vials,
            CAST(NULL AS TEXT) AS evidence_status, CAST(NULL AS UUID) AS actor1,
            CAST(NULL AS TIMESTAMP WITH TIME ZONE) AS time1, CAST(NULL AS TEXT) AS note1,
            CAST(NULL AS UUID) AS actor2, CAST(NULL AS TIMESTAMP WITH TIME ZONE) AS time2,
            CAST(NULL AS TEXT) AS note2 FROM selected
          UNION ALL
          SELECT 'RECEIPT', r.id, r.lot_id, r.vials, CAST(NULL AS TEXT),
            r.received_by, r.received_at, r.difference_note, CAST(NULL AS UUID),
            CAST(NULL AS TIMESTAMP WITH TIME ZONE), CAST(NULL AS TEXT)
          FROM app.inventory_receipts r JOIN selected a ON a.id=r.assignment_id AND a.institution_id=r.institution_id
          UNION ALL
          SELECT 'EVENT', e.id, e.lot_id, e.vial_count, e.status, e.reported_by,
            e.reported_at, e.report_note, e.confirmed_by, e.confirmed_at, e.confirmation_note
          FROM app.inventory_custody_events e JOIN selected a ON a.id=e.assignment_id AND a.institution_id=e.institution_id
        )
        SELECT a.lot_id, a.vaccinator_id, a.vial_count, a.received_vials, a.resolved_vials,
          a.status, e.* FROM selected a CROSS JOIN evidence e
        """,
        (rs, n) -> {
          var assignment = new HistoricalAssignment(rs.getObject("lot_id", UUID.class),
              rs.getObject("vaccinator_id", UUID.class), rs.getInt("vial_count"),
              rs.getInt("received_vials"), rs.getInt("resolved_vials"), rs.getString("status"));
          String kind = rs.getString("evidence_kind");
          UUID id = rs.getObject("evidence_id", UUID.class);
          var time1 = rs.getTimestamp("time1");
          var time2 = rs.getTimestamp("time2");
          HistoricalReceipt receipt = kind.equals("RECEIPT")
              ? new HistoricalReceipt(id, assignmentId, rs.getObject("evidence_lot", UUID.class),
                  rs.getInt("evidence_vials"), rs.getObject("actor1", UUID.class),
                  time1.toInstant(), rs.getString("note1")) : null;
          HistoricalEvent event = kind.equals("EVENT")
              ? new HistoricalEvent(id, assignmentId, rs.getObject("evidence_lot", UUID.class),
                  rs.getInt("evidence_vials"), rs.getString("evidence_status"),
                  rs.getObject("actor1", UUID.class), time1.toInstant(), rs.getString("note1"),
                  rs.getObject("actor2", UUID.class), time2 == null ? null : time2.toInstant(),
                  rs.getString("note2")) : null;
          return new HistoricalRow(assignment, receipt, event);
        }, institutionId, assignmentId);
    if (rows.isEmpty()) throw new IllegalArgumentException("Entrega no encontrada en la institucion.");
    var assignment = rows.getFirst().assignment();
    var receipts = rows.stream().map(HistoricalRow::receipt).filter(Objects::nonNull)
        .sorted(java.util.Comparator.comparing(HistoricalReceipt::receivedAt).thenComparing(HistoricalReceipt::id)).toList();
    var events = rows.stream().map(HistoricalRow::event).filter(Objects::nonNull)
        .sorted(java.util.Comparator.comparing(HistoricalEvent::reportedAt).thenComparing(HistoricalEvent::id)).toList();
    boolean assignmentOnly = receipts.isEmpty() && assignment.received() > 0
        && assignment.status().equals("RECEIVED") && assignment.resolved() == 0
        && assignment.received() == assignment.dispatched();
    var analysis = HistoricalCustodyTransition.inspect(assignmentId, assignment.lot(), assignment.received(),
        assignmentOnly, receipts.stream().map(r -> new HistoricalCustodyTransition.Receipt(
            r.id(), r.assignmentId(), r.lotId(), r.vials())).toList(),
        events.stream().map(e -> new HistoricalCustodyTransition.Event(
            e.id(), e.assignmentId(), e.lotId(), e.status(), e.vials())).toList());
    return new HistoricalReview(assignmentId, assignment.lot(), assignment.custodian(), assignment.dispatched(),
        assignment.received(), assignment.resolved(), assignment.status(), assignmentOnly,
        List.copyOf(receipts), List.copyOf(events), analysis.reasons());
  }

  private record HistoricalAssignment(UUID lot, UUID custodian, int dispatched, int received,
      int resolved, String status) {}
  private record HistoricalRow(HistoricalAssignment assignment, HistoricalReceipt receipt, HistoricalEvent event) {}

  /** Confirma una entrega completa una sola vez; los reintentos identicos son seguros. */
  @Transactional
  public VialTransfer.Assignment receive(UUID actor, UUID institution, UUID assignmentId, int vials) {
    UUID institutionId = authorize(actor, institution, "ATTENTION_CREATE");
    positive(vials);
    Objects.requireNonNull(assignmentId, "assignmentId");
    List<VialTransfer.Assignment> rows = db.query("SELECT id, institution_id, lot_id, vaccinator_id, "
            + "vial_count, status, campaign_id FROM app.inventory_assignments WHERE institution_id = ? "
            + "AND id = ? AND vaccinator_id = ? FOR UPDATE",
        (rs, n) -> new VialTransfer.Assignment(rs.getObject("id", UUID.class),
            rs.getObject("institution_id", UUID.class), rs.getObject("lot_id", UUID.class),
            rs.getObject("vaccinator_id", UUID.class), rs.getObject("campaign_id", UUID.class), rs.getInt("vial_count"),
            VialTransfer.Status.valueOf(rs.getString("status"))), institutionId, assignmentId, actor);
    if (rows.isEmpty()) throw new IllegalArgumentException("Entrega no encontrada para el vacunador.");
    var assignment = rows.getFirst();
    if (assignment.status() == VialTransfer.Status.RECEIVED) {
      if (assignment.vials() != vials) {
        throw new IllegalArgumentException("La cantidad recibida no coincide; requiere una incidencia.");
      }
      return assignment;
    }
    var received = VialTransfer.receive(assignment, actor, vials);
    db.update("UPDATE app.inventory_assignments SET status = 'RECEIVED', received_vials = vial_count, received_at = CURRENT_TIMESTAMP "
        + "WHERE institution_id = ? AND id = ? AND vaccinator_id = ?",
        institutionId, assignmentId, actor);
    return received;
  }

  public record ReceiptResult(UUID id, UUID assignmentId, int acceptedVials,
      int receivedVials, int pendingDifference, String status) {}

  /** Serializa recepciones y novedades en la entrega; el UUID identifica el reintento. */
  @Transactional
  public ReceiptResult receivePartial(UUID actor, UUID institution, UUID assignmentId,
      UUID receiptId, int vials, String note) {
    UUID institutionId = authorize(actor, institution, "ATTENTION_CREATE");
    Objects.requireNonNull(assignmentId, "assignmentId");
    Objects.requireNonNull(receiptId, "receiptId");
    String detail = note == null ? "" : note.trim();
    if (detail.length() > 1000) throw new IllegalArgumentException("La observacion es demasiado larga.");
    var rows = db.query("SELECT lot_id, vial_count, received_vials, resolved_vials, status FROM app.inventory_assignments "
            + "WHERE institution_id = ? AND id = ? AND vaccinator_id = ? FOR UPDATE",
        (rs, n) -> new ReceiptAssignment(rs.getObject("lot_id", UUID.class),
            rs.getInt("vial_count"), rs.getInt("received_vials"), rs.getInt("resolved_vials"), rs.getString("status")),
        institutionId, assignmentId, actor);
    if (rows.isEmpty()) throw new IllegalArgumentException("Entrega no encontrada para el vacunador.");
    var assignment = rows.getFirst();
    var previous = db.query("SELECT assignment_id, received_by, vials, difference_note FROM app.inventory_receipts "
            + "WHERE institution_id = ? AND id = ?",
        (rs, n) -> new PreviousReceipt(rs.getObject("assignment_id", UUID.class),
            rs.getObject("received_by", UUID.class), rs.getInt("vials"), rs.getString("difference_note")),
        institutionId, receiptId);
    if (!previous.isEmpty()) {
      var receipt = previous.getFirst();
      if (!receipt.assignmentId().equals(assignmentId) || !receipt.actor().equals(actor)
          || receipt.vials() != vials || !receipt.note().equals(detail)) {
        throw new IllegalArgumentException("Identificador de recepcion usado con datos diferentes.");
      }
      return new ReceiptResult(receiptId, assignmentId, vials, assignment.received(),
          assignment.total() - assignment.received() - assignment.resolved(), assignment.status());
    }
    PartialReceipt.Balance result;
    if (assignment.status().equals("IN_TRANSIT")) {
      result = PartialReceipt.first(assignment.total(), vials, detail);
    } else if (assignment.status().equals("PARTIALLY_RECEIVED")) {
      result = PartialReceipt.complementary(new PartialReceipt.Balance(
          assignment.total() - assignment.resolved(), assignment.received(),
          assignment.total() - assignment.received() - assignment.resolved()), vials);
    } else {
      throw new IllegalArgumentException("La entrega ya fue recibida.");
    }
    String status = result.pendingDifference() != 0 ? "PARTIALLY_RECEIVED"
        : assignment.resolved() == 0 ? "RECEIVED" : "CLOSED_WITH_DIFFERENCE";
    db.update("INSERT INTO app.inventory_receipts (id, institution_id, assignment_id, lot_id, received_by, "
            + "vials, difference_note) VALUES (?, ?, ?, ?, ?, ?, ?)",
        receiptId, institutionId, assignmentId, assignment.lot(), actor, vials, detail);
    db.update("UPDATE app.inventory_assignments SET received_vials = ?, status = ?, "
            + "received_at = CASE WHEN ? IN ('RECEIVED', 'CLOSED_WITH_DIFFERENCE') THEN CURRENT_TIMESTAMP ELSE received_at END "
            + "WHERE institution_id = ? AND id = ?",
        result.received(), status, status, institutionId, assignmentId);
    return new ReceiptResult(receiptId, assignmentId, vials, result.received(), result.pendingDifference(), status);
  }

  private record ReceiptAssignment(UUID lot, int total, int received, int resolved, String status) {}
  private record PreviousReceipt(UUID assignmentId, UUID actor, int vials, String note) {}

  public record DifferenceResolution(UUID id, UUID assignmentId, String kind, int vialCount,
      String note, UUID recordedBy, Instant recordedAt, int regularizedVials) {}

  @Transactional(readOnly = true)
  public List<DifferenceResolution> listDifferenceResolutions(UUID actor, UUID institution, UUID assignmentId) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_READ");
    Objects.requireNonNull(assignmentId, "assignmentId");
    return db.query("SELECT r.id, r.assignment_id, r.kind, r.vial_count, r.note, r.recorded_by, r.recorded_at, "
            + "(SELECT COALESCE(SUM(g.vial_count), 0) FROM app.inventory_depot_regularizations g "
            + "WHERE g.institution_id = r.institution_id AND g.resolution_id = r.id) AS regularized_vials "
            + "FROM app.inventory_difference_resolutions r WHERE r.institution_id = ? AND r.assignment_id = ? "
            + "ORDER BY r.recorded_at DESC, r.id",
        (rs, n) -> new DifferenceResolution(rs.getObject("id", UUID.class),
            rs.getObject("assignment_id", UUID.class), rs.getString("kind"), rs.getInt("vial_count"),
            rs.getString("note"), rs.getObject("recorded_by", UUID.class),
            rs.getTimestamp("recorded_at").toInstant(), rs.getInt("regularized_vials")), institutionId, assignmentId);
  }

  /** No acredita deposito: la localizacion de correcciones debe verificarse por separado. */
  @Transactional
  public DifferenceResolution resolveDifference(UUID actor, UUID institution, UUID assignmentId,
      UUID resolutionId, String kind, int vials, String note) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_WRITE");
    Objects.requireNonNull(assignmentId, "assignmentId");
    Objects.requireNonNull(resolutionId, "resolutionId");
    positive(vials);
    String detail = requiredText(note);
    if (detail.length() > 1000) throw new IllegalArgumentException("El detalle es demasiado largo.");
    if (!"LOST".equals(kind) && !"DISPATCH_CORRECTION".equals(kind))
      throw new IllegalArgumentException("Tipo de resolucion invalido.");
    var rows = db.query("SELECT lot_id, vial_count, received_vials, resolved_vials, status "
            + "FROM app.inventory_assignments WHERE institution_id = ? AND id = ? FOR UPDATE",
        (rs, n) -> new ReceiptAssignment(rs.getObject("lot_id", UUID.class), rs.getInt("vial_count"),
            rs.getInt("received_vials"), rs.getInt("resolved_vials"), rs.getString("status")),
        institutionId, assignmentId);
    if (rows.isEmpty()) throw new IllegalArgumentException("Entrega no encontrada en la institucion.");
    var assignment = rows.getFirst();
    var existing = db.query("SELECT r.id, r.assignment_id, r.kind, r.vial_count, r.note, r.recorded_by, r.recorded_at, "
            + "(SELECT COALESCE(SUM(g.vial_count), 0) FROM app.inventory_depot_regularizations g "
            + "WHERE g.institution_id = r.institution_id AND g.resolution_id = r.id) AS regularized_vials "
            + "FROM app.inventory_difference_resolutions r WHERE r.institution_id = ? AND r.id = ?",
        (rs, n) -> new DifferenceResolution(rs.getObject("id", UUID.class),
            rs.getObject("assignment_id", UUID.class), rs.getString("kind"), rs.getInt("vial_count"),
            rs.getString("note"), rs.getObject("recorded_by", UUID.class),
            rs.getTimestamp("recorded_at").toInstant(), rs.getInt("regularized_vials")), institutionId, resolutionId);
    if (!existing.isEmpty()) {
      var previous = existing.getFirst();
      if (!previous.assignmentId().equals(assignmentId) || !previous.kind().equals(kind)
          || previous.vialCount() != vials || !previous.note().equals(detail)
          || !previous.recordedBy().equals(actor))
        throw new IllegalArgumentException("Identificador de resolucion usado con datos diferentes.");
      return previous;
    }
    if (!assignment.status().equals("PARTIALLY_RECEIVED"))
      throw new IllegalArgumentException("La entrega no tiene una diferencia pendiente.");
    int pending = assignment.total() - assignment.received() - assignment.resolved();
    if (vials > pending) throw new IllegalArgumentException("La cantidad supera la diferencia pendiente.");
    int resolved = Math.addExact(assignment.resolved(), vials);
    String status = resolved + assignment.received() == assignment.total()
        ? "CLOSED_WITH_DIFFERENCE" : "PARTIALLY_RECEIVED";
    db.update("INSERT INTO app.inventory_difference_resolutions "
            + "(id, institution_id, assignment_id, lot_id, kind, vial_count, note, recorded_by) "
            + "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        resolutionId, institutionId, assignmentId, assignment.lot(), kind, vials, detail, actor);
    db.update("UPDATE app.inventory_assignments SET resolved_vials = ?, status = ? "
            + "WHERE institution_id = ? AND id = ?", resolved, status, institutionId, assignmentId);
    return db.queryForObject("SELECT id, assignment_id, kind, vial_count, note, recorded_by, recorded_at "
            + "FROM app.inventory_difference_resolutions WHERE institution_id = ? AND id = ?",
        (rs, n) -> new DifferenceResolution(rs.getObject("id", UUID.class),
            rs.getObject("assignment_id", UUID.class), rs.getString("kind"), rs.getInt("vial_count"),
            rs.getString("note"), rs.getObject("recorded_by", UUID.class),
            rs.getTimestamp("recorded_at").toInstant(), 0), institutionId, resolutionId);
  }

  public record DepotRegularization(UUID id, UUID resolutionId, int vialCount,
      String note, UUID recordedBy, Instant recordedAt) {}
  private record Correction(UUID assignmentId, UUID lotId, String kind, int vials) {}

  @Transactional(readOnly = true)
  public List<DepotRegularization> listDepotRegularizations(UUID actor, UUID institution, UUID resolutionId) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_READ");
    Objects.requireNonNull(resolutionId, "resolutionId");
    return db.query("SELECT id, resolution_id, vial_count, note, recorded_by, recorded_at "
            + "FROM app.inventory_depot_regularizations WHERE institution_id = ? AND resolution_id = ? "
            + "ORDER BY recorded_at DESC, id",
        (rs, n) -> new DepotRegularization(rs.getObject("id", UUID.class),
            rs.getObject("resolution_id", UUID.class), rs.getInt("vial_count"), rs.getString("note"),
            rs.getObject("recorded_by", UUID.class), rs.getTimestamp("recorded_at").toInstant()),
        institutionId, resolutionId);
  }

  /** Confirma conteo y aptitud; la resolucion y el lote quedan bloqueados hasta commit. */
  @Transactional
  public DepotRegularization regularizeDepot(UUID actor, UUID institution, UUID resolutionId,
      UUID operationId, int vials, String note, boolean physicalAndSuitable) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_WRITE");
    Objects.requireNonNull(resolutionId, "resolutionId");
    Objects.requireNonNull(operationId, "operationId");
    positive(vials);
    String detail = requiredText(note);
    if (detail.length() > 1000) throw new IllegalArgumentException("El detalle es demasiado largo.");
    if (!physicalAndSuitable) throw new IllegalArgumentException("Confirma el conteo fisico y la aptitud.");
    var rows = db.query("SELECT assignment_id, lot_id, kind, vial_count FROM app.inventory_difference_resolutions "
            + "WHERE institution_id = ? AND id = ? FOR UPDATE",
        (rs, n) -> new Correction(rs.getObject("assignment_id", UUID.class), rs.getObject("lot_id", UUID.class),
            rs.getString("kind"), rs.getInt("vial_count")), institutionId, resolutionId);
    if (rows.isEmpty()) throw new IllegalArgumentException("Correccion no encontrada en la institucion.");
    var correction = rows.getFirst();
    var previous = db.query("SELECT id, resolution_id, vial_count, note, recorded_by, recorded_at "
            + "FROM app.inventory_depot_regularizations WHERE institution_id = ? AND id = ?",
        (rs, n) -> new DepotRegularization(rs.getObject("id", UUID.class), rs.getObject("resolution_id", UUID.class),
            rs.getInt("vial_count"), rs.getString("note"), rs.getObject("recorded_by", UUID.class),
            rs.getTimestamp("recorded_at").toInstant()), institutionId, operationId);
    if (!previous.isEmpty()) {
      var record = previous.getFirst();
      if (!record.resolutionId().equals(resolutionId) || record.vialCount() != vials
          || !record.note().equals(detail) || !record.recordedBy().equals(actor))
        throw new IllegalArgumentException("Identificador de regularizacion usado con datos diferentes.");
      return record;
    }
    if (!correction.kind().equals("DISPATCH_CORRECTION"))
      throw new IllegalArgumentException("Solo se regularizan correcciones de despacho.");
    Long already = db.queryForObject("SELECT COALESCE(SUM(vial_count), 0) FROM app.inventory_depot_regularizations "
        + "WHERE institution_id = ? AND resolution_id = ?", Long.class, institutionId, resolutionId);
    if (already == null || already + vials > correction.vials())
      throw new IllegalArgumentException("La cantidad supera los frascos pendientes de verificar.");
    var lot = lockLot(institutionId, correction.lotId());
    if (lot.expiresOn().isBefore(LocalDate.now(clock.withZone(OPERATIONAL_ZONE))))
      throw new IllegalArgumentException("El lote esta vencido y no puede acreditarse como disponible.");
    int updated = Math.addExact(lot.availableVials(), vials);
    db.update("INSERT INTO app.inventory_movements (id, institution_id, lot_id, assignment_id, kind, "
            + "vial_count, occurred_at, recorded_by, note) VALUES (?, ?, ?, ?, 'DEPOT_CORRECTION', ?, CURRENT_TIMESTAMP, ?, ?)",
        operationId, institutionId, correction.lotId(), correction.assignmentId(), vials, actor, detail);
    db.update("INSERT INTO app.inventory_depot_regularizations "
            + "(id, institution_id, resolution_id, vial_count, note, recorded_by) VALUES (?, ?, ?, ?, ?, ?)",
        operationId, institutionId, resolutionId, vials, detail, actor);
    db.update("UPDATE app.inventory_lots SET available_vials = ? WHERE institution_id = ? AND id = ?",
        updated, institutionId, correction.lotId());
    return db.queryForObject("SELECT id, resolution_id, vial_count, note, recorded_by, recorded_at "
            + "FROM app.inventory_depot_regularizations WHERE institution_id = ? AND id = ?",
        (rs, n) -> new DepotRegularization(rs.getObject("id", UUID.class), rs.getObject("resolution_id", UUID.class),
            rs.getInt("vial_count"), rs.getString("note"), rs.getObject("recorded_by", UUID.class),
            rs.getTimestamp("recorded_at").toInstant()), institutionId, operationId);
  }

  /** El movimiento identifica la intención; un reintento idéntico no vuelve a acreditar. */
  @Transactional
  public void recordEntry(UUID actor, UUID institution, UUID movementId, UUID lotId,
      int vials, Instant occurredAt, String note) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_WRITE");
    positive(vials);
    Objects.requireNonNull(movementId, "movementId");
    Objects.requireNonNull(occurredAt, "occurredAt");
    String reason = requiredText(note);
    int available = lockLot(institutionId, lotId).availableVials();
    var existing = findMovement(institutionId, movementId);
    if (existing != null) {
      checkMovement(existing, "ENTRY", lotId, null, vials, occurredAt, actor, reason);
      return;
    }
    int updated = Math.addExact(available, vials);
    db.update("INSERT INTO app.inventory_movements (id, institution_id, lot_id, kind, vial_count, "
        + "occurred_at, recorded_by, note) VALUES (?, ?, ?, 'ENTRY', ?, ?, ?, ?)",
        movementId, institutionId, lotId, vials, java.sql.Timestamp.from(occurredAt.truncatedTo(ChronoUnit.MICROS)), actor, reason);
    db.update("UPDATE app.inventory_lots SET available_vials = ? WHERE institution_id = ? AND id = ?",
        updated, institutionId, lotId);
  }

  /** La fila del lote permanece bloqueada hasta confirmar movimiento, entrega y saldo. */
  @Transactional
  public VialTransfer.Assignment dispatch(UUID actor, UUID institution, UUID movementId,
      UUID assignmentId, UUID lotId, UUID vaccinatorId, int vials, Instant occurredAt, String note) {
    return dispatch(actor, institution, movementId, assignmentId, lotId, vaccinatorId, vials, occurredAt, note, null);
  }

  @Transactional
  public VialTransfer.Assignment dispatch(UUID actor, UUID institution, UUID movementId,
      UUID assignmentId, UUID lotId, UUID vaccinatorId, int vials, Instant occurredAt, String note, UUID campaignId) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_WRITE");
    Objects.requireNonNull(movementId, "movementId");
    Objects.requireNonNull(assignmentId, "assignmentId");
    Objects.requireNonNull(lotId, "lotId");
    Objects.requireNonNull(vaccinatorId, "vaccinatorId");
    positive(vials);
    Objects.requireNonNull(occurredAt, "occurredAt");
    String reason = requiredText(note);
    var existing = findMovement(institutionId, movementId);
    if (existing != null) return replayDispatch(existing, institutionId, actor,
        assignmentId, lotId, vaccinatorId, campaignId, vials, occurredAt, reason);
    if (campaignId != null) CampaignService.lockActive(db, institutionId, campaignId);
    CampaignService.requireVaccinator(db, institutionId, vaccinatorId);
    var lotBalance = lockLot(institutionId, lotId);
    existing = findMovement(institutionId, movementId);
    if (existing != null) return replayDispatch(existing, institutionId, actor,
        assignmentId, lotId, vaccinatorId, campaignId, vials, occurredAt, reason);
    if (lotBalance.expiresOn().isBefore(LocalDate.now(clock.withZone(OPERATIONAL_ZONE)))) {
      throw new IllegalArgumentException("No se pueden entregar frascos de un lote vencido.");
    }
    int available = lotBalance.availableVials();
    var transfer = VialTransfer.dispatch(assignmentId, institutionId, lotId, vaccinatorId,
        campaignId, available, vials);
    if (campaignId != null) CampaignService.addParticipantIfAbsent(db, institutionId, campaignId, vaccinatorId, actor);
    db.update("INSERT INTO app.inventory_assignments (id, institution_id, lot_id, vaccinator_id, "
        + "vial_count, status, dispatched_by, campaign_id) VALUES (?, ?, ?, ?, ?, 'IN_TRANSIT', ?, ?)",
        assignmentId, institutionId, lotId, vaccinatorId, vials, actor, campaignId);
    db.update("INSERT INTO app.inventory_movements (id, institution_id, lot_id, assignment_id, "
        + "kind, vial_count, occurred_at, recorded_by, note) VALUES (?, ?, ?, ?, 'DISPATCH', ?, ?, ?, ?)",
        movementId, institutionId, lotId, assignmentId, vials,
        java.sql.Timestamp.from(occurredAt.truncatedTo(ChronoUnit.MICROS)), actor, reason);
    db.update("UPDATE app.inventory_lots SET available_vials = ? WHERE institution_id = ? AND id = ?",
        transfer.remainingVials(), institutionId, lotId);
    events.publishEvent(new InventoryChange("DELIVERY_CREATED", institutionId, assignmentId,
        movementId, vaccinatorId));
    return transfer.assignment();
  }

  private record StoredMovement(UUID lot, UUID assignment, String kind, int vials,
      Instant occurredAt, UUID actor, String note) {}

  private StoredMovement findMovement(UUID institution, UUID movementId) {
    var rows = db.query("SELECT lot_id, assignment_id, kind, vial_count, occurred_at, recorded_by, note "
            + "FROM app.inventory_movements WHERE institution_id = ? AND id = ?",
        (rs, n) -> new StoredMovement(rs.getObject("lot_id", UUID.class),
            rs.getObject("assignment_id", UUID.class), rs.getString("kind"), rs.getInt("vial_count"),
            rs.getTimestamp("occurred_at").toInstant(), rs.getObject("recorded_by", UUID.class),
            rs.getString("note")), institution, movementId);
    return rows.isEmpty() ? null : rows.getFirst();
  }

  private void checkMovement(StoredMovement stored, String kind, UUID lot, UUID assignment,
      int vials, Instant occurredAt, UUID actor, String note) {
    if (!stored.kind().equals(kind) || !Objects.equals(stored.lot(), lot)
        || !Objects.equals(stored.assignment(), assignment) || stored.vials() != vials
        || !stored.occurredAt().equals(occurredAt.truncatedTo(ChronoUnit.MICROS))
        || !Objects.equals(stored.actor(), actor) || !stored.note().equals(note))
      throw new IllegalArgumentException("Identificador de movimiento usado con datos diferentes.");
  }

  /** El estado devuelto es el actual, no necesariamente el estado inicial del despacho. */
  private VialTransfer.Assignment replayDispatch(StoredMovement stored, UUID institution, UUID actor,
      UUID assignmentId, UUID lotId, UUID vaccinatorId, UUID campaignId,
      int vials, Instant occurredAt, String reason) {
    checkMovement(stored, "DISPATCH", lotId, assignmentId, vials, occurredAt, actor, reason);
    var rows = db.query("SELECT vaccinator_id, campaign_id, vial_count, status, lot_id "
            + "FROM app.inventory_assignments WHERE institution_id = ? AND id = ?",
        (rs, n) -> new VialTransfer.Assignment(assignmentId, institution,
            rs.getObject("lot_id", UUID.class), rs.getObject("vaccinator_id", UUID.class),
            rs.getObject("campaign_id", UUID.class), rs.getInt("vial_count"),
            VialTransfer.Status.valueOf(rs.getString("status"))), institution, assignmentId);
    if (rows.isEmpty()) throw new IllegalStateException("El despacho no tiene una entrega asociada.");
    var assignment = rows.getFirst();
    if (!assignment.lotId().equals(lotId) || !assignment.vaccinatorId().equals(vaccinatorId)
        || !Objects.equals(assignment.campaignId(), campaignId) || assignment.vials() != vials)
      throw new IllegalArgumentException("Identificador de despacho usado con datos diferentes.");
    return assignment;
  }

  private record LotBalance(int availableVials, LocalDate expiresOn) {}

  private LotBalance lockLot(UUID institution, UUID lot) {
    Objects.requireNonNull(lot, "lot");
    List<LotBalance> rows = db.query("SELECT available_vials, expires_on FROM app.inventory_lots "
        + "WHERE institution_id = ? AND id = ? FOR UPDATE",
        (rs, n) -> new LotBalance(rs.getInt("available_vials"),
            rs.getObject("expires_on", LocalDate.class)), institution, lot);
    if (rows.isEmpty()) throw new IllegalArgumentException("Lote no encontrado en la institucion.");
    return rows.getFirst();
  }

  private static void positive(int value) {
    if (value <= 0) throw new IllegalArgumentException("La cantidad debe ser positiva.");
  }

  private static String requiredText(String text) {
    if (text == null || text.isBlank()) throw new IllegalArgumentException("El texto es obligatorio.");
    return text.trim();
  }
}
