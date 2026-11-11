package com.pai.api.inventory.security;

import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.security.PermissionGuard;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Propagation;

/** Abre una conciliacion y revoca; no recupera stock ni autoriza otro dispositivo. */
@Service
public class InstallationRecoveryService {
  /** Permiso separado; deliberadamente no asignado a ningun rol por esta funcionalidad. */
  public static final String QUARANTINE_PAYLOAD_READ = "QUARANTINE_PAYLOAD_READ";
  private final JdbcTemplate db;
  private final PermissionGuard guard;
  private final DataScope scope;
  private final InstallationKeyService keys;
  public InstallationRecoveryService(JdbcTemplate db, PermissionGuard guard, DataScope scope, InstallationKeyService keys) {
    this.db = db;
    this.guard = guard;
    this.scope = scope;
    this.keys = keys;
  }

  private record Existing(UUID id, UUID openedBy, String reason) {}
  public record Review(UUID id, UUID reservationId, int observedVials, int reservedVialsAtReview,
      String note, UUID reviewedBy) {}
  public record Replacement(UUID installationId, UUID linkedBy, String note) {}
  public record ReviewDecision(UUID id, UUID reviewId, String disposition, String rationale, UUID decidedBy) {}
  public record EventReview(UUID id, UUID eventId, String disposition, String rationale, UUID reviewedBy) {}
  public record QuarantinedEvent(UUID id, long sequenceNumber, String status) {}
  /** Los conteos no prueban conciliacion sanitaria ni ausencia de eventos tardios. */
  public record ClosureAssessment(long reservations, long withoutReview, boolean replacementKeyActive,
      boolean lateEventsVerified, boolean closureAllowed) {}
  private record CaseInstallation(UUID id, UUID owner) {}

  /** La revocacion y el caso se confirman o revierten en la misma transaccion. */
  @Transactional
  public UUID open(UUID actor, UUID institution, UUID installation, UUID caseId, String reason) {
    UUID scoped = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_WRITE"), Objects.requireNonNull(institution));
    Objects.requireNonNull(installation);
    Objects.requireNonNull(caseId);
    if (reason == null || reason.isBlank() || reason.trim().length() > 1000)
      throw new IllegalArgumentException("El motivo es obligatorio.");
    // revoke bloquea la instalacion y serializa apertura frente a otras aperturas y altas.
    keys.revoke(actor, scoped, installation, reason.trim());
    List<Existing> existing = db.query("SELECT id, opened_by, reason FROM app.inventory_installation_recovery_cases "
            + "WHERE institution_id=? AND installation_id=?",
        (rs, n) -> new Existing(rs.getObject("id", UUID.class), rs.getObject("opened_by", UUID.class), rs.getString("reason")),
        scoped, installation);
    if (!existing.isEmpty()) {
      var prior = existing.getFirst();
      if (!prior.id().equals(caseId) || !prior.openedBy().equals(actor) || !prior.reason().equals(reason.trim()))
        throw new IllegalArgumentException("Ya existe un caso de recuperacion para esta instalacion.");
      return prior.id();
    }
    int inserted = db.update("INSERT INTO app.inventory_installation_recovery_cases "
        + "(id, institution_id, installation_id, vaccinator_id, opened_by, reason) "
        + "SELECT ?, institution_id, id, vaccinator_id, ?, ? FROM app.inventory_installations WHERE institution_id=? AND id=?",
        caseId, actor, reason.trim(), scoped, installation);
    if (inserted != 1) throw new IllegalArgumentException("Instalacion no encontrada.");
    return caseId;
  }

  /** Registra una observacion fisica por reserva, sin resolver ni transferir la custodia. */
  @Transactional
  public Review review(UUID actor, UUID institution, UUID caseId, UUID reviewId, UUID reservationId,
      int observedVials, String note) {
    UUID scoped = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_WRITE"), Objects.requireNonNull(institution));
    Objects.requireNonNull(caseId);
    Objects.requireNonNull(reviewId);
    Objects.requireNonNull(reservationId);
    if (observedVials < 0 || note == null || note.isBlank() || note.trim().length() > 1000)
      throw new IllegalArgumentException("Conteo o detalle invalido.");
    var cases = db.query("SELECT installation_id FROM app.inventory_installation_recovery_cases "
        + "WHERE institution_id=? AND id=? AND status='OPEN' FOR UPDATE",
        (rs, n) -> rs.getObject(1, UUID.class), scoped, caseId);
    if (cases.isEmpty()) throw new IllegalArgumentException("Caso abierto no encontrado.");
    UUID installation = cases.getFirst();
    var previous = db.query("SELECT id, reservation_id, observed_vials, reserved_vials_at_review, note, reviewed_by "
        + "FROM app.inventory_installation_recovery_reviews WHERE institution_id=? AND case_id=? AND id=?",
        (rs, n) -> new Review(rs.getObject("id", UUID.class), rs.getObject("reservation_id", UUID.class),
            rs.getInt("observed_vials"), rs.getInt("reserved_vials_at_review"), rs.getString("note"),
            rs.getObject("reviewed_by", UUID.class)), scoped, caseId, reviewId);
    if (!previous.isEmpty()) {
      Review prior = previous.getFirst();
      if (!prior.reservationId().equals(reservationId) || prior.observedVials() != observedVials
          || !prior.note().equals(note.trim()) || !prior.reviewedBy().equals(actor))
        throw new IllegalArgumentException("El identificador de revision ya tiene otros datos.");
      return prior;
    }
    List<Integer> reserved = db.query("SELECT vial_count FROM app.inventory_installation_reservations "
            + "WHERE institution_id=? AND installation_id=? AND id=?",
        (rs, n) -> rs.getInt(1), scoped, installation, reservationId);
    if (reserved.isEmpty()) throw new IllegalArgumentException("Reserva no encontrada para este caso.");
    int amount = reserved.getFirst();
    db.update("INSERT INTO app.inventory_installation_recovery_reviews (id, institution_id, case_id, installation_id, "
        + "reservation_id, observed_vials, reserved_vials_at_review, note, reviewed_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        reviewId, scoped, caseId, installation, reservationId, observedVials, amount, note.trim(), actor);
    return new Review(reviewId, reservationId, observedVials, amount, note.trim(), actor);
  }

  @Transactional(readOnly = true)
  public List<Review> listReviews(UUID actor, UUID institution, UUID caseId) {
    UUID scoped = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_READ"), Objects.requireNonNull(institution));
    return db.query("SELECT id, reservation_id, observed_vials, reserved_vials_at_review, note, reviewed_by "
        + "FROM app.inventory_installation_recovery_reviews WHERE institution_id=? AND case_id=? ORDER BY reviewed_at, id",
        (rs, n) -> new Review(rs.getObject("id", UUID.class), rs.getObject("reservation_id", UUID.class),
            rs.getInt("observed_vials"), rs.getInt("reserved_vials_at_review"), rs.getString("note"),
            rs.getObject("reviewed_by", UUID.class)), scoped, Objects.requireNonNull(caseId));
  }

  /** Dictamen documental versionado por UUID; nunca modifica saldos ni habilita cierre. */
  @Transactional
  public ReviewDecision decideReview(UUID actor, UUID institution, UUID caseId, UUID reviewId,
      UUID decisionId, String disposition, String rationale) {
    UUID scoped = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_WRITE"), Objects.requireNonNull(institution));
    Objects.requireNonNull(caseId);
    Objects.requireNonNull(reviewId);
    Objects.requireNonNull(decisionId);
    if (disposition == null || !List.of("DOCUMENTED", "NEEDS_INVESTIGATION").contains(disposition)
        || rationale == null || rationale.isBlank() || rationale.trim().length() > 1000)
      throw new IllegalArgumentException("Dictamen o fundamento invalido.");
    var cases = db.query("SELECT id FROM app.inventory_installation_recovery_cases WHERE institution_id=? "
        + "AND id=? AND status='OPEN' FOR UPDATE", (rs, n) -> rs.getObject(1, UUID.class), scoped, caseId);
    if (cases.isEmpty()) throw new IllegalArgumentException("Caso abierto no encontrado.");
    var previous = db.query("SELECT id, review_id, disposition, rationale, decided_by "
        + "FROM app.inventory_recovery_review_decisions WHERE institution_id=? AND case_id=? AND id=?",
        (rs, n) -> new ReviewDecision(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class),
            rs.getString(3), rs.getString(4), rs.getObject(5, UUID.class)), scoped, caseId, decisionId);
    if (!previous.isEmpty()) {
      var old = previous.getFirst();
      if (!old.reviewId().equals(reviewId) || !old.disposition().equals(disposition)
          || !old.rationale().equals(rationale.trim()) || !old.decidedBy().equals(actor))
        throw new IllegalArgumentException("El identificador de dictamen ya tiene otros datos.");
      return old;
    }
    Integer exists = db.queryForObject("SELECT count(*) FROM app.inventory_installation_recovery_reviews "
        + "WHERE institution_id=? AND case_id=? AND id=?", Integer.class, scoped, caseId, reviewId);
    if (exists == null || exists != 1) throw new IllegalArgumentException("Revision no encontrada en el caso.");
    db.update("INSERT INTO app.inventory_recovery_review_decisions "
        + "(id, institution_id, case_id, review_id, disposition, rationale, decided_by) VALUES (?, ?, ?, ?, ?, ?, ?)",
        decisionId, scoped, caseId, reviewId, disposition, rationale.trim(), actor);
    return new ReviewDecision(decisionId, reviewId, disposition, rationale.trim(), actor);
  }

  /** Auditoria documental; ni el dictamen ni el reintento aplican el evento. */
  @Transactional
  public EventReview reviewEvent(UUID actor, UUID institution, UUID caseId, UUID eventId, UUID reviewId,
      String disposition, String rationale) {
    UUID scoped = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_WRITE"), Objects.requireNonNull(institution));
    Objects.requireNonNull(caseId); Objects.requireNonNull(eventId); Objects.requireNonNull(reviewId);
    if (disposition == null || !List.of("DOCUMENTED", "NEEDS_INVESTIGATION").contains(disposition)
        || rationale == null || rationale.isBlank() || rationale.trim().length() > 1000)
      throw new IllegalArgumentException("Dictamen o fundamento invalido.");
    var cases = db.query("SELECT installation_id FROM app.inventory_installation_recovery_cases "
        + "WHERE institution_id=? AND id=? AND status='OPEN' FOR UPDATE",
        (rs, n) -> rs.getObject(1, UUID.class), scoped, caseId);
    if (cases.isEmpty()) throw new IllegalArgumentException("Caso abierto no encontrado.");
    var previous = db.query("SELECT id, event_id, disposition, rationale, reviewed_by "
        + "FROM app.inventory_quarantined_event_reviews WHERE institution_id=? AND case_id=? AND id=?",
        (rs, n) -> new EventReview(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class),
            rs.getString(3), rs.getString(4), rs.getObject(5, UUID.class)), scoped, caseId, reviewId);
    if (!previous.isEmpty()) {
      var old = previous.getFirst();
      if (!old.eventId().equals(eventId) || !old.disposition().equals(disposition)
          || !old.rationale().equals(rationale.trim()) || !old.reviewedBy().equals(actor))
        throw new IllegalArgumentException("El identificador de revision ya tiene otros datos.");
      return old;
    }
    UUID installation = cases.getFirst();
    Integer exists = db.queryForObject("SELECT count(*) FROM app.inventory_quarantined_installation_events "
        + "WHERE institution_id=? AND installation_id=? AND id=? AND status='QUARANTINED'",
        Integer.class, scoped, installation, eventId);
    if (exists == null || exists != 1) throw new IllegalArgumentException("Evento en cuarentena no encontrado para este caso.");
    db.update("INSERT INTO app.inventory_quarantined_event_reviews (id, institution_id, installation_id, case_id, "
        + "event_id, disposition, rationale, reviewed_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        reviewId, scoped, installation, caseId, eventId, disposition, rationale.trim(), actor);
    return new EventReview(reviewId, eventId, disposition, rationale.trim(), actor);
  }

  @Transactional(readOnly = true)
  public List<EventReview> listEventReviews(UUID actor, UUID institution, UUID caseId) {
    UUID scoped = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_READ"), Objects.requireNonNull(institution));
    return db.query("SELECT id, event_id, disposition, rationale, reviewed_by FROM app.inventory_quarantined_event_reviews "
        + "WHERE institution_id=? AND case_id=? ORDER BY reviewed_at, id",
        (rs, n) -> new EventReview(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class),
            rs.getString(3), rs.getString(4), rs.getObject(5, UUID.class)), scoped, Objects.requireNonNull(caseId));
  }

  /** Solo metadatos: el acceso al contenido clinico requiere controles aun no definidos. */
  @Transactional(readOnly = true)
  public List<QuarantinedEvent> listCaseEvents(UUID actor, UUID institution, UUID caseId) {
    UUID scoped = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_READ"), Objects.requireNonNull(institution));
    return db.query("SELECT e.id, e.sequence_number, e.status FROM app.inventory_quarantined_installation_events e "
        + "JOIN app.inventory_installation_recovery_cases c ON c.institution_id=e.institution_id "
        + "AND c.installation_id=e.installation_id WHERE c.institution_id=? AND c.id=? ORDER BY e.sequence_number, e.id",
        (rs, n) -> new QuarantinedEvent(rs.getObject(1, UUID.class), rs.getLong(2), rs.getString(3)),
        scoped, Objects.requireNonNull(caseId));
  }

  /** La transaccion independiente debe confirmar auditoria antes de devolver contenido al llamador. */
  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public byte[] readQuarantinedPayload(UUID actor, UUID institution, UUID caseId, UUID eventId,
      UUID accessId, String reason) {
    UUID scoped = scope.resolveInstitutionId(guard.require(actor, QUARANTINE_PAYLOAD_READ), Objects.requireNonNull(institution));
    Objects.requireNonNull(caseId); Objects.requireNonNull(eventId); Objects.requireNonNull(accessId);
    if (reason == null || reason.isBlank() || reason.trim().length() > 1000)
      throw new IllegalArgumentException("El motivo de acceso es obligatorio.");
    var cases = db.query("SELECT installation_id FROM app.inventory_installation_recovery_cases "
        + "WHERE institution_id=? AND id=? AND status='OPEN' FOR UPDATE",
        (rs, n) -> rs.getObject(1, UUID.class), scoped, caseId);
    if (cases.isEmpty()) throw new IllegalArgumentException("Caso abierto no encontrado.");
    UUID installation = cases.getFirst();
    var payloads = db.query("SELECT payload FROM app.inventory_quarantined_installation_events "
        + "WHERE institution_id=? AND installation_id=? AND id=? AND status='QUARANTINED'",
        (rs, n) -> rs.getBytes(1), scoped, installation, eventId);
    if (payloads.isEmpty()) throw new IllegalArgumentException("Evento en cuarentena no encontrado para este caso.");
    // Una lectura nueva requiere un identificador nuevo; un duplicado no devuelve contenido sin registrar la lectura.
    db.update("INSERT INTO app.inventory_quarantined_event_access_audit (id, institution_id, installation_id, "
        + "case_id, event_id, accessed_by, reason) VALUES (?, ?, ?, ?, ?, ?, ?)",
        accessId, scoped, installation, caseId, eventId, actor, reason.trim());
    return payloads.getFirst().clone();
  }

  /** Diagnostico informativo; no hay protocolo para verificar eventos offline tardios. */
  @Transactional(readOnly = true)
  public ClosureAssessment assessClosure(UUID actor, UUID institution, UUID caseId) {
    UUID scoped = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_READ"), Objects.requireNonNull(institution));
    var cases = db.query("SELECT installation_id FROM app.inventory_installation_recovery_cases "
        + "WHERE institution_id=? AND id=? AND status='OPEN'",
        (rs, n) -> rs.getObject(1, UUID.class), scoped, Objects.requireNonNull(caseId));
    if (cases.isEmpty()) throw new IllegalArgumentException("Caso abierto no encontrado.");
    UUID installation = cases.getFirst();
    Long total = db.queryForObject("SELECT count(*) FROM app.inventory_installation_reservations "
        + "WHERE institution_id=? AND installation_id=?", Long.class, scoped, installation);
    Long unreviewed = db.queryForObject("SELECT count(*) FROM app.inventory_installation_reservations r "
        + "WHERE r.institution_id=? AND r.installation_id=? AND NOT EXISTS "
        + "(SELECT 1 FROM app.inventory_installation_recovery_reviews v "
        + "WHERE v.institution_id=r.institution_id AND v.case_id=? AND v.reservation_id=r.id)",
        Long.class, scoped, installation, caseId);
    Integer active = db.queryForObject("SELECT count(*) FROM app.inventory_installation_recovery_replacements p "
        + "JOIN app.inventory_installation_keys k ON k.institution_id=p.institution_id "
        + "AND k.installation_id=p.replacement_installation_id WHERE p.institution_id=? AND p.case_id=? AND k.status='ACTIVE'",
        Integer.class, scoped, caseId);
    // Nunca interpretar el numero de revisiones como evidencia de que no quedan eventos por sincronizar.
    return new ClosureAssessment(Objects.requireNonNull(total), Objects.requireNonNull(unreviewed),
        active != null && active == 1, false, false);
  }

  /** Vincula un reemplazo activo; no transfiere reservas ni resuelve eventos tardios. */
  @Transactional
  public Replacement linkReplacement(UUID actor, UUID institution, UUID caseId, UUID replacementId, String note) {
    UUID scoped = scope.resolveInstitutionId(guard.require(actor, "INVENTORY_WRITE"), Objects.requireNonNull(institution));
    Objects.requireNonNull(caseId);
    Objects.requireNonNull(replacementId);
    if (note == null || note.isBlank() || note.trim().length() > 1000)
      throw new IllegalArgumentException("El detalle es obligatorio.");
    var cases = db.query("SELECT installation_id, vaccinator_id FROM app.inventory_installation_recovery_cases "
        + "WHERE institution_id=? AND id=? AND status='OPEN' FOR UPDATE",
        (rs, n) -> new CaseInstallation(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class)), scoped, caseId);
    if (cases.isEmpty()) throw new IllegalArgumentException("Caso abierto no encontrado.");
    var original = cases.getFirst();
    var prior = db.query("SELECT replacement_installation_id, linked_by, note "
        + "FROM app.inventory_installation_recovery_replacements WHERE institution_id=? AND case_id=?",
        (rs, n) -> new Replacement(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class), rs.getString(3)), scoped, caseId);
    if (!prior.isEmpty()) {
      Replacement existing = prior.getFirst();
      if (!existing.installationId().equals(replacementId) || !existing.linkedBy().equals(actor) || !existing.note().equals(note.trim()))
        throw new IllegalArgumentException("El caso ya tiene una sustitucion registrada.");
      return existing;
    }
    if (original.id().equals(replacementId)) throw new IllegalArgumentException("La sustitucion debe ser otra instalacion.");
    var target = db.query("SELECT id FROM app.inventory_installations WHERE institution_id=? "
        + "AND id=? AND vaccinator_id=? FOR UPDATE", (rs, n) -> rs.getObject(1, UUID.class),
        scoped, replacementId, original.owner());
    if (target.isEmpty()) throw new IllegalArgumentException("La sustitucion no pertenece al vacunador o institucion.");
    Integer active = db.queryForObject("SELECT count(*) FROM app.inventory_installation_keys "
        + "WHERE institution_id=? AND installation_id=? AND status='ACTIVE'", Integer.class, scoped, replacementId);
    if (active == null || active != 1) throw new IllegalArgumentException("La sustitucion requiere una clave activa.");
    db.update("INSERT INTO app.inventory_installation_recovery_replacements (case_id, institution_id, old_installation_id, "
        + "replacement_installation_id, vaccinator_id, linked_by, note) VALUES (?, ?, ?, ?, ?, ?, ?)",
        caseId, scoped, original.id(), replacementId, original.owner(), actor, note.trim());
    return new Replacement(replacementId, actor, note.trim());
  }
}
