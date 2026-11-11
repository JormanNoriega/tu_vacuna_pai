package com.pai.api.inventory.security;

import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.security.PermissionGuard;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Alta y revocacion internas; no autoriza operaciones de consumo ni recuperacion. */
@Service
public class InstallationKeyService {
  private final JdbcTemplate db;
  private final PermissionGuard guard;
  private final DataScope scope;
  private final InstallationChallengeService challenges;

  public InstallationKeyService(JdbcTemplate db, PermissionGuard guard, DataScope scope,
      InstallationChallengeService challenges) {
    this.db = db;
    this.guard = guard;
    this.scope = scope;
    this.challenges = challenges;
  }

  @Transactional
  public InstallationChallengeService.Challenge begin(UUID actor, UUID institution, UUID installation, byte[] key) {
    UUID scoped = authorize(actor, institution, "ATTENTION_CREATE");
    lockInstallation(scoped, installation, actor);
    requireUnenrolled(scoped, installation);
    return challenges.issue(scoped, actor, installation, key);
  }

  @Transactional
  public boolean complete(UUID actor, UUID institution, UUID installation, UUID challenge, byte[] key, byte[] signature) {
    UUID scoped = authorize(actor, institution, "ATTENTION_CREATE");
    lockInstallation(scoped, installation, actor);
    requireUnenrolled(scoped, installation);
    List<byte[]> stored = db.query("SELECT public_key FROM app.inventory_installation_proof_challenges "
        + "WHERE id=? AND institution_id=? AND actor_id=? AND installation_id=?",
        (rs, n) -> rs.getBytes(1), challenge, scoped, actor, installation);
    if (stored.isEmpty() || key == null || !Arrays.equals(stored.getFirst(), key)) return false;
    if (!challenges.consume(challenge, scoped, actor, installation, signature)) return false;
    db.update("INSERT INTO app.inventory_installation_keys (installation_id, institution_id, vaccinator_id, "
        + "public_key, status, enrolled_at) VALUES (?, ?, ?, ?, 'ACTIVE', clock_timestamp())",
        installation, scoped, actor, key);
    return true;
  }

  /** Revocar incluso un alta pendiente impide que un desafio anterior active la instalacion. */
  @Transactional
  public void revoke(UUID actor, UUID institution, UUID installation, String note) {
    UUID scoped = authorize(actor, institution, "INVENTORY_WRITE");
    if (note == null || note.isBlank() || note.trim().length() > 1000)
      throw new IllegalArgumentException("El motivo de revocacion es obligatorio.");
    UUID owner = lockInstallation(scoped, installation, null);
    List<String> states = db.query("SELECT status FROM app.inventory_installation_keys WHERE installation_id=? AND institution_id=?",
        (rs, n) -> rs.getString(1), installation, scoped);
    if (states.isEmpty()) {
      db.update("INSERT INTO app.inventory_installation_keys (installation_id, institution_id, vaccinator_id, status, "
          + "revoked_at, revoked_by, revocation_note) VALUES (?, ?, ?, 'REVOKED', clock_timestamp(), ?, ?)",
          installation, scoped, owner, actor, note.trim());
    } else if (!states.getFirst().equals("REVOKED")) {
      db.update("UPDATE app.inventory_installation_keys SET status='REVOKED', revoked_at=clock_timestamp(), "
          + "revoked_by=?, revocation_note=? WHERE installation_id=? AND institution_id=?",
          actor, note.trim(), installation, scoped);
    }
    db.update("UPDATE app.inventory_installation_proof_challenges SET consumed_at=clock_timestamp() "
        + "WHERE institution_id=? AND installation_id=? AND consumed_at IS NULL", scoped, installation);
  }

  private UUID authorize(UUID actor, UUID institution, String permission) {
    return scope.resolveInstitutionId(guard.require(actor, permission), Objects.requireNonNull(institution));
  }

  private UUID lockInstallation(UUID institution, UUID installation, UUID owner) {
    List<UUID> rows = db.query("SELECT vaccinator_id FROM app.inventory_installations "
        + "WHERE institution_id=? AND id=? FOR UPDATE", (rs, n) -> rs.getObject(1, UUID.class), institution, installation);
    if (rows.isEmpty() || (owner != null && !owner.equals(rows.getFirst())))
      throw new IllegalArgumentException("Instalacion no encontrada para el usuario o institucion.");
    return rows.getFirst();
  }

  private void requireUnenrolled(UUID institution, UUID installation) {
    Integer count = db.queryForObject("SELECT count(*) FROM app.inventory_installation_keys "
        + "WHERE institution_id=? AND installation_id=?", Integer.class, institution, installation);
    if (count == null || count != 0) throw new IllegalArgumentException("La instalacion ya tiene clave o fue revocada.");
  }
}
