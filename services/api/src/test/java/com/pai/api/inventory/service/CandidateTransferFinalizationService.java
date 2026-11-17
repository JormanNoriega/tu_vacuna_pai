package com.pai.api.inventory.service;

import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.security.PermissionGuard;
import java.util.Objects;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;

/** Prototipo de prueba. No es bean, API ni cierre operativo. */
final class CandidateTransferFinalizationService {
  private final JdbcTemplate db;
  private final PermissionGuard guard;
  private final DataScope scope;

  CandidateTransferFinalizationService(JdbcTemplate db, PermissionGuard guard, DataScope scope) {
    this.db = db;
    this.guard = guard;
    this.scope = scope;
  }

  private record Assignment(UUID lot, UUID vaccinator, int sent, int received, int resolved, String status) {}
  private record Previous(UUID id, String kind, UUID actor, String evidence) {}

  @Transactional
  UUID finalizeTransfer(UUID actor, UUID institution, UUID assignmentId, UUID operationId,
      boolean administratorReview, String evidence) {
    String permission = administratorReview ? "INVENTORY_WRITE" : "ATTENTION_CREATE";
    UUID institutionId = scope.resolveInstitutionId(guard.require(actor, permission),
        Objects.requireNonNull(institution, "institution"));
    Objects.requireNonNull(assignmentId, "assignmentId");
    Objects.requireNonNull(operationId, "operationId");
    String note = evidence == null ? "" : evidence.trim();
    if (note.length() > 1000 || (administratorReview ? note.isEmpty() : !note.isEmpty()))
      throw new IllegalArgumentException("Evidencia de finalizacion invalida.");
    String kind = administratorReview ? "ADMIN_REVIEW" : "AUTOMATIC";
    var rows = db.query("SELECT lot_id, vaccinator_id, vial_count, received_vials, resolved_vials, status "
            + "FROM app.inventory_assignments WHERE institution_id=? AND id=? FOR UPDATE",
        (rs, n) -> new Assignment(rs.getObject("lot_id", UUID.class), rs.getObject("vaccinator_id", UUID.class),
            rs.getInt("vial_count"), rs.getInt("received_vials"), rs.getInt("resolved_vials"), rs.getString("status")),
        institutionId, assignmentId);
    if (rows.isEmpty()) throw new IllegalArgumentException("Entrega no encontrada.");
    var assignment = rows.getFirst();
    if (!administratorReview && !assignment.vaccinator().equals(actor))
      throw new IllegalArgumentException("Solo el destinatario puede confirmar la recepcion.");
    var previous = db.query("SELECT id, kind, recorded_by, evidence FROM app.transfer_finalizations_candidate "
            + "WHERE institution_id=? AND assignment_id=?",
        (rs, n) -> new Previous(rs.getObject("id", UUID.class), rs.getString("kind"),
            rs.getObject("recorded_by", UUID.class), rs.getString("evidence")), institutionId, assignmentId);
    if (!previous.isEmpty()) {
      var prior = previous.getFirst();
      if (!prior.id().equals(operationId) || !prior.kind().equals(kind)
          || !prior.actor().equals(actor) || !prior.evidence().equals(note))
        throw new IllegalArgumentException("La entrega ya tiene otra finalizacion.");
      return operationId;
    }
    if (assignment.sent() <= 0 || assignment.received() < 0 || assignment.resolved() < 0
        || (long) assignment.received() + assignment.resolved() != assignment.sent()
        || (!assignment.status().equals("RECEIVED") && !assignment.status().equals("CLOSED_WITH_DIFFERENCE")))
      throw new IllegalArgumentException("La diferencia de traslado sigue pendiente.");
    var receipts = db.queryForMap("SELECT COUNT(*) AS n, COALESCE(SUM(vials),0) AS total, "
            + "COALESCE(SUM(CASE WHEN lot_id <> ? OR received_by <> ? OR vials < 0 THEN 1 ELSE 0 END),0) AS invalid, "
            + "COALESCE(SUM(CASE WHEN length(trim(difference_note)) > 0 THEN 1 ELSE 0 END),0) AS notes "
            + "FROM app.inventory_receipts WHERE institution_id=? AND assignment_id=?",
        assignment.lot(), assignment.vaccinator(), institutionId, assignmentId);
    long count = ((Number) receipts.get("n")).longValue();
    long total = ((Number) receipts.get("total")).longValue();
    long notes = ((Number) receipts.get("notes")).longValue();
    boolean legacyFull = count == 0 && assignment.status().equals("RECEIVED")
        && assignment.resolved() == 0 && assignment.received() == assignment.sent();
    if (((Number) receipts.get("invalid")).longValue() != 0
        || (!legacyFull && (count == 0 || total != assignment.received())))
      throw new IllegalArgumentException("La evidencia de recepcion requiere revision.");
    Long events = db.queryForObject("SELECT COUNT(*) FROM app.inventory_custody_events "
        + "WHERE institution_id=? AND assignment_id=?", Long.class, institutionId, assignmentId);
    // Sin origen verificable para automatizar historias anteriores a la tabla de recepciones.
    if (!administratorReview && (legacyFull || assignment.resolved() != 0 || count != 1
        || notes != 0 || events == null || events != 0))
      throw new IllegalArgumentException("La entrega requiere revision administrativa.");
    db.update("INSERT INTO app.transfer_finalizations_candidate "
            + "(id,institution_id,assignment_id,lot_id,kind,recorded_by,evidence) VALUES (?,?,?,?,?,?,?)",
        operationId, institutionId, assignmentId, assignment.lot(), kind, actor, note);
    return operationId;
  }
}
