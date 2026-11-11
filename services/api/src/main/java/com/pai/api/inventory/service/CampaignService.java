package com.pai.api.inventory.service;

import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.security.PermissionGuard;
import java.time.LocalDate;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Jornada online: su finalizacion nunca mueve stock ni cierra entregas. */
@Service
public class CampaignService {
  private final JdbcTemplate db;
  private final PermissionGuard guard;
  private final DataScope scope;

  public CampaignService(JdbcTemplate db, PermissionGuard guard, DataScope scope) {
    this.db = db;
    this.guard = guard;
    this.scope = scope;
  }

  public record Campaign(UUID id, String name, String location, LocalDate startsOn,
      LocalDate endsOn, String status) {}
  public record Participant(UUID id, String name) {}

  private UUID authorize(UUID actor, UUID institution, String permission) {
    Objects.requireNonNull(institution, "institution");
    return scope.resolveInstitutionId(guard.require(actor, permission), institution);
  }

  @Transactional
  public void create(UUID actor, UUID institution, UUID id, String name, String location,
      LocalDate startsOn, LocalDate endsOn) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_WRITE");
    Objects.requireNonNull(id, "id");
    Objects.requireNonNull(startsOn, "startsOn");
    Objects.requireNonNull(endsOn, "endsOn");
    if (endsOn.isBefore(startsOn)) throw new IllegalArgumentException("La fecha final es anterior al inicio.");
    if (name == null || name.isBlank() || name.trim().length() > 200
        || location == null || location.isBlank() || location.trim().length() > 200) {
      throw new IllegalArgumentException("Nombre y lugar son obligatorios, maximo 200 caracteres.");
    }
    db.update("INSERT INTO app.inventory_campaigns (id, institution_id, name, location, starts_on, ends_on, "
        + "status, created_by) VALUES (?, ?, ?, ?, ?, ?, 'ACTIVE', ?)",
        id, institutionId, name.trim(), location.trim(), startsOn, endsOn, actor);
  }

  @Transactional(readOnly = true)
  public List<Campaign> list(UUID actor, UUID institution) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_READ");
    return db.query("SELECT id, name, location, starts_on, ends_on, status FROM app.inventory_campaigns "
            + "WHERE institution_id = ? ORDER BY starts_on DESC, id",
        (rs, n) -> new Campaign(rs.getObject("id", UUID.class), rs.getString("name"),
            rs.getString("location"), rs.getObject("starts_on", LocalDate.class),
            rs.getObject("ends_on", LocalDate.class), rs.getString("status")), institutionId);
  }

  @Transactional(readOnly = true)
  public List<Participant> participants(UUID actor, UUID institution, UUID campaignId) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_READ");
    return db.query("SELECT u.id, u.full_name FROM app.inventory_campaign_participants p "
            + "JOIN app.users u ON u.id = p.vaccinator_id WHERE p.institution_id = ? AND p.campaign_id = ? "
            + "ORDER BY u.full_name, u.id", (rs, n) -> new Participant(rs.getObject("id", UUID.class),
                rs.getString("full_name")), institutionId, campaignId);
  }

  @Transactional
  public void addParticipant(UUID actor, UUID institution, UUID campaignId, UUID vaccinatorId) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_WRITE");
    lockActive(db, institutionId, campaignId);
    requireVaccinator(db, institutionId, vaccinatorId);
    addParticipantIfAbsent(db, institutionId, campaignId, vaccinatorId, actor);
  }

  @Transactional
  public void finish(UUID actor, UUID institution, UUID campaignId) {
    UUID institutionId = authorize(actor, institution, "INVENTORY_WRITE");
    List<String> states = db.query("SELECT status FROM app.inventory_campaigns "
        + "WHERE institution_id = ? AND id = ? FOR UPDATE", (rs, n) -> rs.getString(1), institutionId, campaignId);
    if (states.isEmpty()) throw new IllegalArgumentException("Jornada no encontrada en la institucion.");
    if (states.getFirst().equals("FINISHED")) return;
    db.update("UPDATE app.inventory_campaigns SET status = 'FINISHED', finished_at = CURRENT_TIMESTAMP, "
        + "finished_by = ? WHERE institution_id = ? AND id = ?", actor, institutionId, campaignId);
  }

  static void lockActive(JdbcTemplate db, UUID institution, UUID campaignId) {
    List<String> states = db.query("SELECT status FROM app.inventory_campaigns "
        + "WHERE institution_id = ? AND id = ? FOR UPDATE", (rs, n) -> rs.getString(1), institution, campaignId);
    if (states.isEmpty()) throw new IllegalArgumentException("Jornada no encontrada en la institucion.");
    if (!states.getFirst().equals("ACTIVE")) throw new IllegalArgumentException("La jornada ya finalizo.");
  }

  static void requireVaccinator(JdbcTemplate db, UUID institution, UUID vaccinatorId) {
    Integer eligible = db.queryForObject("SELECT count(*) FROM app.users u "
        + "JOIN app.user_roles ur ON ur.user_id = u.id JOIN app.roles r ON r.id = ur.role_id "
        + "WHERE u.id = ? AND u.institution_id = ? AND u.status = 'ACTIVE' AND r.code = 'VACCINATOR'",
        Integer.class, vaccinatorId, institution);
    if (eligible == null || eligible == 0) throw new IllegalArgumentException("El vacunador no esta activo en la institucion.");
  }

  static void addParticipantIfAbsent(JdbcTemplate db, UUID institution, UUID campaignId, UUID vaccinatorId, UUID actor) {
    Integer existing = db.queryForObject("SELECT count(*) FROM app.inventory_campaign_participants "
        + "WHERE institution_id = ? AND campaign_id = ? AND vaccinator_id = ?", Integer.class,
        institution, campaignId, vaccinatorId);
    if (existing == 0) db.update("INSERT INTO app.inventory_campaign_participants "
        + "(institution_id, campaign_id, vaccinator_id, added_by) VALUES (?, ?, ?, ?)", institution, campaignId, vaccinatorId, actor);
  }
}
