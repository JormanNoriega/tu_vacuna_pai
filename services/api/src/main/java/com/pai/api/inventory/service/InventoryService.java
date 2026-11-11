package com.pai.api.inventory.service;

import com.pai.api.identity.service.DataScope;
import com.pai.api.inventory.domain.VialTransfer;
import com.pai.api.shared.security.PermissionGuard;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Operaciones online iniciales. No reserva cuotas offline ni consume dosis clinicas. */
@Service
public class InventoryService {
  private final JdbcTemplate db;
  private final PermissionGuard guard;
  private final DataScope scope;

  public InventoryService(JdbcTemplate db, PermissionGuard guard, DataScope scope) {
    this.db = db;
    this.guard = guard;
    this.scope = scope;
  }

  public record Lot(UUID id, UUID vaccineId, String vaccineName, String manufacturer, String lotNumber,
      LocalDate expiresOn, int dosesPerVial, int availableVials) {}

  public record AssignmentView(UUID id, UUID lotId, UUID vaccinatorId, int vialCount,
      String status, Instant dispatchedAt, String lotNumber, String vaccineName, UUID campaignId, String campaignName) {}

  public record MovementView(UUID id, String vaccineName, String lotNumber, String kind,
      int vialCount, Instant occurredAt, String note) {}

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
    createLot(actor, institution, id, vaccineId, manufacturer, lotNumber, expiresOn, dosesPerVial);
    recordEntry(actor, institution, movementId, id, vials, occurredAt, note);
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
    Objects.requireNonNull(id, "id");
    Objects.requireNonNull(vaccineId, "vaccineId");
    Objects.requireNonNull(expiresOn, "expiresOn");
    String maker = requiredText(manufacturer);
    String number = requiredText(lotNumber);
    if (dosesPerVial <= 0) throw new IllegalArgumentException("La capacidad debe ser positiva.");
    db.update("INSERT INTO app.inventory_lots (id, institution_id, vaccine_id, manufacturer, "
        + "lot_number, expires_on, doses_per_vial, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        id, institutionId, vaccineId, maker, number, expiresOn, dosesPerVial, actor);
    return id;
  }

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
            rs.getString("lot_number"), rs.getString("vaccine_name"), rs.getObject("campaign_id", UUID.class), rs.getString("campaign_name")),
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
            rs.getString("lot_number"), rs.getString("vaccine_name"), rs.getObject("campaign_id", UUID.class), rs.getString("campaign_name")),
        institutionId, actor);
  }

  private String assignmentQuery() {
    return "SELECT a.id, a.lot_id, a.vaccinator_id, a.vial_count, a.status, a.dispatched_at, a.campaign_id, "
        + "l.lot_number, v.name AS vaccine_name, c.name AS campaign_name FROM app.inventory_assignments a "
        + "JOIN app.inventory_lots l ON l.id = a.lot_id AND l.institution_id = a.institution_id "
        + "JOIN app.vaccines v ON v.id = l.vaccine_id "
        + "LEFT JOIN app.inventory_campaigns c ON c.id = a.campaign_id AND c.institution_id = a.institution_id";
  }

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
    db.update("UPDATE app.inventory_assignments SET status = 'RECEIVED', received_at = CURRENT_TIMESTAMP "
        + "WHERE institution_id = ? AND id = ? AND vaccinator_id = ?",
        institutionId, assignmentId, actor);
    return received;
  }

  /** El UUID de movimiento es unico incluso si se reintenta la peticion. */
  @Transactional
  public void recordEntry(UUID actor, UUID institution, UUID movementId, UUID lotId,
      int vials, Instant occurredAt, String note) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_WRITE");
    positive(vials);
    Objects.requireNonNull(movementId, "movementId");
    Objects.requireNonNull(occurredAt, "occurredAt");
    String reason = requiredText(note);
    int available = lockLot(institutionId, lotId);
    int updated = Math.addExact(available, vials);
    db.update("INSERT INTO app.inventory_movements (id, institution_id, lot_id, kind, vial_count, "
        + "occurred_at, recorded_by, note) VALUES (?, ?, ?, 'ENTRY', ?, ?, ?, ?)",
        movementId, institutionId, lotId, vials, java.sql.Timestamp.from(occurredAt), actor, reason);
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
    Objects.requireNonNull(occurredAt, "occurredAt");
    String reason = requiredText(note);
    if (campaignId != null) CampaignService.lockActive(db, institutionId, campaignId);
    CampaignService.requireVaccinator(db, institutionId, vaccinatorId);
    int available = lockLot(institutionId, lotId);
    var transfer = VialTransfer.dispatch(assignmentId, institutionId, lotId, vaccinatorId,
        campaignId, available, vials);
    if (campaignId != null) CampaignService.addParticipantIfAbsent(db, institutionId, campaignId, vaccinatorId, actor);
    db.update("INSERT INTO app.inventory_assignments (id, institution_id, lot_id, vaccinator_id, "
        + "vial_count, status, dispatched_by, campaign_id) VALUES (?, ?, ?, ?, ?, 'IN_TRANSIT', ?, ?)",
        assignmentId, institutionId, lotId, vaccinatorId, vials, actor, campaignId);
    db.update("INSERT INTO app.inventory_movements (id, institution_id, lot_id, assignment_id, "
        + "kind, vial_count, occurred_at, recorded_by, note) VALUES (?, ?, ?, ?, 'DISPATCH', ?, ?, ?, ?)",
        movementId, institutionId, lotId, assignmentId, vials, java.sql.Timestamp.from(occurredAt), actor, reason);
    db.update("UPDATE app.inventory_lots SET available_vials = ? WHERE institution_id = ? AND id = ?",
        transfer.remainingVials(), institutionId, lotId);
    return transfer.assignment();
  }

  private int lockLot(UUID institution, UUID lot) {
    Objects.requireNonNull(lot, "lot");
    List<Integer> rows = db.query("SELECT available_vials FROM app.inventory_lots "
        + "WHERE institution_id = ? AND id = ? FOR UPDATE", (rs, n) -> rs.getInt(1), institution, lot);
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
