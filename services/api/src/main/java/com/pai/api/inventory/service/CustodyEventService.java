package com.pai.api.inventory.service;

import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.security.PermissionGuard;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Frascos cerrados declarados: no se calcula consumo ni disponibilidad sanitaria. */
@Service
public class CustodyEventService {
  private final JdbcTemplate db;
  private final PermissionGuard guard;
  private final DataScope scope;
  public CustodyEventService(JdbcTemplate db, PermissionGuard guard, DataScope scope) {
    this.db = db;
    this.guard = guard;
    this.scope = scope;
  }

  public record Event(UUID id, UUID assignmentId, UUID lotId, int vialCount, String status,
      String reportNote, String confirmationNote, String vaccineName, String lotNumber) {}

  private UUID authorize(UUID actor, UUID institution, String permission) {
    Objects.requireNonNull(institution, "institution");
    return scope.resolveInstitutionId(guard.require(actor, permission), institution);
  }

  /** El custodio declara una devolucion o novedad, sin cambiar el saldo del deposito. */
  @Transactional
  public void report(UUID actor, UUID institution, UUID id, UUID assignmentId,
      int vials, String kind, String note) {
    UUID institutionId = authorize(actor, institution, "ATTENTION_CREATE");
    Objects.requireNonNull(id, "id");
    if (vials <= 0) throw new IllegalArgumentException("La cantidad debe ser positiva.");
    String status = switch (kind == null ? "" : kind) {
      case "RETURN" -> "RETURN_PENDING";
      case "LOST" -> "INCIDENT_LOST";
      case "QUARANTINE" -> "INCIDENT_QUARANTINED";
      default -> throw new IllegalArgumentException("Tipo de novedad invalido.");
    };
    String detail = requiredText(note);
    var rows = db.query("SELECT lot_id, vial_count, status FROM app.inventory_assignments "
            + "WHERE institution_id = ? AND id = ? AND vaccinator_id = ? FOR UPDATE",
        (rs, n) -> new Assignment(rs.getObject("lot_id", UUID.class), rs.getInt("vial_count"), rs.getString("status")),
        institutionId, assignmentId, actor);
    if (rows.isEmpty()) throw new IllegalArgumentException("Entrega no encontrada para el vacunador.");
    Assignment assignment = rows.getFirst();
    if (!assignment.status().equals("RECEIVED")) throw new IllegalArgumentException("Primero confirma la recepcion de la entrega.");
    Long recorded = db.queryForObject("SELECT COALESCE(SUM(vial_count), 0) FROM app.inventory_custody_events "
        + "WHERE institution_id = ? AND assignment_id = ?", Long.class, institutionId, assignmentId);
    // Una incidencia puede afectar frascos comprometidos y siempre debe poder
    // registrarse. No libera ni reduce la reserva: el solapamiento es conservador.
    // Una devolucion, en cambio, no puede devolver al deposito un frasco reservado.
    long reserved = status.equals("RETURN_PENDING")
        ? InstallationReservationService.sum(db, "inventory_installation_reservations", institutionId, assignmentId) : 0;
    if (recorded == null || recorded + reserved + vials > assignment.vials()) {
      throw new IllegalArgumentException("La cantidad supera los frascos no declarados de esta entrega.");
    }
    db.update("INSERT INTO app.inventory_custody_events (id, institution_id, lot_id, assignment_id, "
        + "vial_count, status, reported_by, report_note) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        id, institutionId, assignment.lot(), assignmentId, vials, status, actor, detail);
  }

  /** Solo el responsable institucional confirma recepcion fisica y destino explicito. */
  @Transactional
  public void confirmReturn(UUID actor, UUID institution, UUID eventId, String disposition, String note) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_WRITE");
    String status = switch (disposition == null ? "" : disposition) {
      case "AVAILABLE" -> "RETURN_AVAILABLE";
      case "QUARANTINE" -> "RETURN_QUARANTINED";
      default -> throw new IllegalArgumentException("Selecciona un destino valido.");
    };
    String detail = requiredText(note);
    var events = db.query("SELECT assignment_id, lot_id, vial_count, status, confirmation_note "
            + "FROM app.inventory_custody_events WHERE institution_id = ? AND id = ? FOR UPDATE",
        (rs, n) -> new Pending(rs.getObject("assignment_id", UUID.class), rs.getObject("lot_id", UUID.class),
            rs.getInt("vial_count"), rs.getString("status"), rs.getString("confirmation_note")), institutionId, eventId);
    if (events.isEmpty()) throw new IllegalArgumentException("Devolucion no encontrada.");
    var event = events.getFirst();
    if (event.status().equals(status) && Objects.equals(event.confirmationNote(), detail)) return;
    if (!event.status().equals("RETURN_PENDING")) throw new IllegalArgumentException("La devolucion ya fue confirmada o es una incidencia.");
    if (status.equals("RETURN_AVAILABLE")) {
      List<Integer> balances = db.query("SELECT available_vials FROM app.inventory_lots "
          + "WHERE institution_id = ? AND id = ? FOR UPDATE", (rs, n) -> rs.getInt(1), institutionId, event.lot());
      if (balances.isEmpty()) throw new IllegalArgumentException("Lote no encontrado.");
      int balance = Math.addExact(balances.getFirst(), event.vials());
      db.update("INSERT INTO app.inventory_movements (id, institution_id, lot_id, assignment_id, kind, "
          + "vial_count, occurred_at, recorded_by, note) VALUES (?, ?, ?, ?, 'RETURN', ?, CURRENT_TIMESTAMP, ?, ?)",
          eventId, institutionId, event.lot(), event.assignment(), event.vials(), actor, detail);
      db.update("UPDATE app.inventory_lots SET available_vials = ? WHERE institution_id = ? AND id = ?",
          balance, institutionId, event.lot());
    }
    db.update("UPDATE app.inventory_custody_events SET status = ?, confirmed_by = ?, "
        + "confirmed_at = CURRENT_TIMESTAMP, confirmation_note = ? WHERE institution_id = ? AND id = ?",
        status, actor, detail, institutionId, eventId);
  }

  @Transactional(readOnly = true)
  public List<Event> list(UUID actor, UUID institution, boolean mine) {
    UUID institutionId = authorize(actor, institution, mine ? "ATTENTION_CREATE" : "INVENTORY_READ");
    String sql = "SELECT e.id, e.assignment_id, e.lot_id, e.vial_count, e.status, e.report_note, "
        + "e.confirmation_note, v.name AS vaccine_name, l.lot_number FROM app.inventory_custody_events e "
        + "JOIN app.inventory_lots l ON l.id=e.lot_id AND l.institution_id=e.institution_id "
        + "JOIN app.vaccines v ON v.id=l.vaccine_id WHERE e.institution_id = ?";
    if (mine) sql += " AND e.reported_by = ?";
    sql += " ORDER BY e.reported_at DESC, e.id";
    var mapper = (org.springframework.jdbc.core.RowMapper<Event>) (rs, n) -> new Event(
        rs.getObject("id", UUID.class), rs.getObject("assignment_id", UUID.class),
        rs.getObject("lot_id", UUID.class), rs.getInt("vial_count"), rs.getString("status"),
        rs.getString("report_note"), rs.getString("confirmation_note"), rs.getString("vaccine_name"), rs.getString("lot_number"));
    return mine ? db.query(sql, mapper, institutionId, actor) : db.query(sql, mapper, institutionId);
  }

  private static String requiredText(String value) {
    if (value == null || value.isBlank() || value.trim().length() > 1000)
      throw new IllegalArgumentException("El detalle es obligatorio y admite hasta 1000 caracteres.");
    return value.trim();
  }
  private record Assignment(UUID lot, int vials, String status) {}
  private record Pending(UUID assignment, UUID lot, int vials, String status, String confirmationNote) {}
}
