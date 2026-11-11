package com.pai.api.inventory.service;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.security.PermissionGuard;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Registro contable experimental. Un UUID no autentica una instalacion. */
@Service
public class InstallationReservationService {
  private final JdbcTemplate db;
  private final PermissionGuard guard;
  private final DataScope scope;

  public InstallationReservationService(JdbcTemplate db, PermissionGuard guard, DataScope scope) {
    this.db = db;
    this.guard = guard;
    this.scope = scope;
  }

  public record Installation(UUID id, UUID vaccinatorId, String label) {}
  public record Reservation(UUID id, UUID assignmentId, UUID installationId, int vialCount) {}
  private record Assignment(UUID lot, UUID owner, int vials, String status) {}

  @Transactional
  public void register(UUID actorId, UUID institution, UUID installationId, String label) {
    Objects.requireNonNull(institution, "institution");
    Objects.requireNonNull(installationId, "installationId");
    AuthorizedUser actor = guard.require(actorId, "ATTENTION_CREATE");
    UUID institutionId = scope.resolveInstitutionId(actor, institution);
    if (!actor.getRoles().contains("VACCINATOR")) throw new IllegalArgumentException("Se requiere un vacunador activo.");
    if (label == null || label.isBlank() || label.trim().length() > 80)
      throw new IllegalArgumentException("La etiqueta es obligatoria y admite hasta 80 caracteres.");
    CampaignService.requireVaccinator(db, institutionId, actorId);
    List<Installation> existing = db.query("SELECT id, vaccinator_id, label FROM app.inventory_installations "
        + "WHERE institution_id=? AND id=? AND vaccinator_id=?", (rs, n) -> new Installation(
            rs.getObject("id", UUID.class), rs.getObject("vaccinator_id", UUID.class), rs.getString("label")),
        institutionId, installationId, actorId);
    if (!existing.isEmpty()) {
      if (!existing.getFirst().label().equals(label.trim())) throw new IllegalArgumentException("El identificador ya tiene otra etiqueta.");
      return;
    }
    db.update("INSERT INTO app.inventory_installations (id, institution_id, vaccinator_id, label) VALUES (?, ?, ?, ?)",
        installationId, institutionId, actorId, label.trim());
  }

  @Transactional(readOnly = true)
  public List<Installation> list(UUID actor, UUID institution) {
    UUID institutionId = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_READ"),
        Objects.requireNonNull(institution, "institution"));
    return db.query("SELECT id, vaccinator_id, label FROM app.inventory_installations WHERE institution_id=? ORDER BY created_at, id",
        (rs, n) -> new Installation(rs.getObject("id", UUID.class), rs.getObject("vaccinator_id", UUID.class),
            rs.getString("label")), institutionId);
  }

  @Transactional(readOnly = true)
  public List<Reservation> listReservations(UUID actor, UUID institution) {
    UUID institutionId = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_READ"),
        Objects.requireNonNull(institution, "institution"));
    return db.query("SELECT id, assignment_id, installation_id, vial_count "
        + "FROM app.inventory_installation_reservations WHERE institution_id=? ORDER BY created_at, id",
        (rs, n) -> new Reservation(rs.getObject("id", UUID.class), rs.getObject("assignment_id", UUID.class),
            rs.getObject("installation_id", UUID.class), rs.getInt("vial_count")), institutionId);
  }

  /** El bloqueo de la entrega serializa reservas y declaraciones de novedad. */
  @Transactional
  public Reservation reserve(UUID actor, UUID institution, UUID reservationId,
      UUID assignmentId, UUID installationId, int vials) {
    UUID institutionId = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_WRITE"),
        Objects.requireNonNull(institution, "institution"));
    Objects.requireNonNull(reservationId, "reservationId");
    Objects.requireNonNull(assignmentId, "assignmentId");
    Objects.requireNonNull(installationId, "installationId");
    if (vials <= 0) throw new IllegalArgumentException("La cantidad debe ser positiva.");
    var rows = db.query("SELECT lot_id, vaccinator_id, vial_count, status FROM app.inventory_assignments "
            + "WHERE institution_id=? AND id=? FOR UPDATE",
        (rs, n) -> new Assignment(rs.getObject("lot_id", UUID.class), rs.getObject("vaccinator_id", UUID.class),
            rs.getInt("vial_count"), rs.getString("status")), institutionId, assignmentId);
    if (rows.isEmpty()) throw new IllegalArgumentException("Entrega no encontrada en la institucion.");
    var assignment = rows.getFirst();
    if (!assignment.status().equals("RECEIVED")) throw new IllegalArgumentException("La entrega debe estar recibida.");
    CampaignService.requireVaccinator(db, institutionId, assignment.owner());
    // El orden es entrega -> instalacion. La revocacion bloquea esa misma instalacion
    // y no bloquea entregas; asi no se crea un ciclo de bloqueos entre ambos flujos.
    var installations = db.query("SELECT id FROM app.inventory_installations "
        + "WHERE institution_id=? AND id=? AND vaccinator_id=? FOR UPDATE",
        (rs, n) -> rs.getObject(1, UUID.class), institutionId, installationId, assignment.owner());
    if (installations.isEmpty())
      throw new IllegalArgumentException("La instalacion no pertenece al vacunador de la entrega.");
    var previous = db.query("SELECT id, assignment_id, installation_id, vial_count FROM app.inventory_installation_reservations "
            + "WHERE institution_id=? AND id=?", (rs, n) -> new Reservation(rs.getObject("id", UUID.class),
                rs.getObject("assignment_id", UUID.class), rs.getObject("installation_id", UUID.class), rs.getInt("vial_count")),
        institutionId, reservationId);
    if (!previous.isEmpty()) {
      Reservation result = previous.getFirst();
      if (!result.assignmentId().equals(assignmentId) || !result.installationId().equals(installationId) || result.vialCount() != vials)
        throw new IllegalArgumentException("Identificador de reserva usado con datos diferentes.");
      return result;
    }
    Integer revoked = db.queryForObject("SELECT count(*) FROM app.inventory_installation_keys "
        + "WHERE institution_id=? AND installation_id=? AND status='REVOKED'",
        Integer.class, institutionId, installationId);
    if (revoked == null || revoked != 0)
      throw new IllegalArgumentException("La instalacion esta revocada; no admite nuevas reservas.");
    long reported = sum(db, "inventory_custody_events", institutionId, assignmentId);
    long reserved = sum(db, "inventory_installation_reservations", institutionId, assignmentId);
    if (reported + reserved + vials > assignment.vials())
      throw new IllegalArgumentException("No hay suficientes frascos sin comprometer en la entrega.");
    db.update("INSERT INTO app.inventory_installation_reservations (id, institution_id, lot_id, assignment_id, "
        + "vaccinator_id, installation_id, vial_count, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        reservationId, institutionId, assignment.lot(), assignmentId, assignment.owner(), installationId, vials, actor);
    return new Reservation(reservationId, assignmentId, installationId, vials);
  }

  static long sum(JdbcTemplate db, String table, UUID institution, UUID assignment) {
    if (!table.equals("inventory_custody_events") && !table.equals("inventory_installation_reservations"))
      throw new IllegalArgumentException("Tabla no autorizada.");
    Long value = db.queryForObject("SELECT COALESCE(SUM(vial_count),0) FROM app." + table
        + " WHERE institution_id=? AND assignment_id=?", Long.class, institution, assignment);
    return Objects.requireNonNull(value);
  }
}
