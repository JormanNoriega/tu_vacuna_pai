package com.pai.api.inventory.service;

import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.security.PermissionGuard;
import java.util.Objects;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;

/**
 * Prototipo solo de prueba: no es bean, endpoint ni funcionalidad desplegable.
 * La transaccion debe aplicarse mediante proxy o TransactionTemplate.
 */
final class CandidateCustodyLinkService {
  private final JdbcTemplate db;
  private final PermissionGuard guard;
  private final DataScope scope;

  CandidateCustodyLinkService(JdbcTemplate db, PermissionGuard guard, DataScope scope) {
    this.db = db;
    this.guard = guard;
    this.scope = scope;
  }

  private record Assignment(UUID lot, UUID custodian, int sent, int received, int resolved, String status) {}
  private record Link(UUID custody, UUID actor) {}

  @Transactional
  UUID link(UUID actor, UUID institution, UUID custodyId, UUID assignmentId) {
    UUID institutionId = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_WRITE"),
        Objects.requireNonNull(institution, "institution"));
    return linkAuthorized(actor, institutionId, custodyId, assignmentId, null);
  }

  /** Solo prueba: derivar vinculo de una recepcion propia ya registrada en la transaccion. */
  UUID linkFromReceipt(CandidateReceiptOrchestrator.ReceiptProof proof) {
    Objects.requireNonNull(proof, "proof").claim(db);
    UUID institutionId = scope.resolveInstitutionId(guard.require(proof.actor(), "ATTENTION_CREATE"),
        proof.institution());
    return linkAuthorized(proof.actor(), institutionId, proof.custody(), proof.assignment(), proof.receipt());
  }

  private UUID linkAuthorized(UUID actor, UUID institutionId, UUID custodyId, UUID assignmentId, UUID receiptId) {
    Objects.requireNonNull(custodyId, "custodyId");
    Objects.requireNonNull(assignmentId, "assignmentId");
    var institutions = db.query("SELECT id FROM app.institutions WHERE id=? FOR UPDATE",
        (rs, n) -> rs.getObject("id", UUID.class), institutionId);
    if (institutions.isEmpty()) throw new IllegalArgumentException("Institucion no encontrada.");
    var assignments = db.query("SELECT lot_id, vaccinator_id, vial_count, received_vials, resolved_vials, status "
            + "FROM app.inventory_assignments WHERE institution_id=? AND id=? FOR UPDATE",
        (rs, n) -> new Assignment(rs.getObject("lot_id", UUID.class), rs.getObject("vaccinator_id", UUID.class),
            rs.getInt("vial_count"), rs.getInt("received_vials"), rs.getInt("resolved_vials"), rs.getString("status")),
        institutionId, assignmentId);
    if (assignments.isEmpty()) throw new IllegalArgumentException("Entrega no encontrada.");
    var assignment = assignments.getFirst();
    if (receiptId != null) {
      if (!assignment.custodian().equals(actor))
        throw new IllegalArgumentException("La entrega pertenece a otro vacunador.");
      var receiptCount = db.queryForObject("SELECT count(*) FROM app.inventory_receipts "
              + "WHERE id=? AND institution_id=? AND assignment_id=? AND lot_id=? AND received_by=? AND vials>0",
          Integer.class, receiptId, institutionId, assignmentId, assignment.lot(), actor);
      if (receiptCount == null || receiptCount != 1)
        throw new IllegalArgumentException("Recepcion propia verificable no encontrada.");
    }
    var userCount = db.queryForObject("SELECT count(*) FROM app.users WHERE id=? AND institution_id=? AND status='ACTIVE'",
        Integer.class, assignment.custodian(), institutionId);
    if (userCount == null || userCount != 1) throw new IllegalArgumentException("Custodio no valido en la institucion.");
    var previous = db.query("SELECT custody_id, linked_by FROM app.individual_custody_origins_candidate "
            + "WHERE institution_id=? AND assignment_id=?",
        (rs, n) -> new Link(rs.getObject("custody_id", UUID.class), rs.getObject("linked_by", UUID.class)),
        institutionId, assignmentId);
    if (!previous.isEmpty()) {
      var link = previous.getFirst();
      if (!link.custody().equals(custodyId) || (receiptId == null && !link.actor().equals(actor)))
        throw new IllegalArgumentException("La entrega ya tiene otra vinculacion.");
      return custodyId;
    }
    if (assignment.received() <= 0 || assignment.received() > assignment.sent()
        || assignment.resolved() < 0 || (long) assignment.received() + assignment.resolved() > assignment.sent()
        || !java.util.Set.of("RECEIVED", "PARTIALLY_RECEIVED", "CLOSED_WITH_DIFFERENCE").contains(assignment.status()))
      throw new IllegalArgumentException("No hay recepcion fisica verificable.");
    var receipts = db.queryForMap("SELECT COUNT(*) AS n, COALESCE(SUM(vials),0) AS total, "
        + "COALESCE(SUM(CASE WHEN lot_id <> ? OR received_by <> ? OR vials < 0 THEN 1 ELSE 0 END),0) AS invalid "
        + "FROM app.inventory_receipts WHERE institution_id=? AND assignment_id=?",
        assignment.lot(), assignment.custodian(), institutionId, assignmentId);
    long count = ((Number) receipts.get("n")).longValue();
    long total = ((Number) receipts.get("total")).longValue();
    boolean legacy = count == 0 && assignment.status().equals("RECEIVED")
        && assignment.resolved() == 0 && assignment.received() == assignment.sent();
    if (((Number) receipts.get("invalid")).longValue() != 0 || (!legacy && (count == 0 || total != assignment.received())))
      throw new IllegalArgumentException("Las recepciones requieren revision.");
    var existing = db.query("SELECT id FROM app.individual_custodies_candidate "
            + "WHERE institution_id=? AND lot_id=? AND custodian_id=?",
        (rs, n) -> rs.getObject("id", UUID.class), institutionId, assignment.lot(), assignment.custodian());
    if (existing.isEmpty()) {
      db.update("INSERT INTO app.individual_custodies_candidate (id, institution_id, lot_id, custodian_id, created_by) "
          + "VALUES (?, ?, ?, ?, ?)", custodyId, institutionId, assignment.lot(), assignment.custodian(), actor);
    } else if (!existing.getFirst().equals(custodyId)) {
      throw new IllegalArgumentException("La custodia ya existe con otro identificador.");
    }
    db.update("INSERT INTO app.individual_custody_origins_candidate "
            + "(assignment_id, institution_id, lot_id, custodian_id, custody_id, linked_by) VALUES (?, ?, ?, ?, ?, ?)",
        assignmentId, institutionId, assignment.lot(), assignment.custodian(), custodyId, actor);
    return custodyId;
  }
}
