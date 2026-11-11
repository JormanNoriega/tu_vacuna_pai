package com.pai.api.inventory.security;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Infraestructura interna experimental, no es una API de autenticacion o alta de claves. */
@Service
public class InstallationChallengeService {
  private static final Duration LIFETIME = Duration.ofMinutes(2);
  private final JdbcTemplate db;
  private final SecureRandom random = new SecureRandom();

  public InstallationChallengeService(JdbcTemplate db) { this.db = db; }

  public record Challenge(UUID id, byte[] nonce, Instant expiresAt) {}
  private record Stored(byte[] key, byte[] nonce, Instant expiresAt, Instant consumedAt) {}

  /** El llamador futuro debe autorizar al actor y validar el alta de la clave. */
  @Transactional
  public Challenge issue(UUID institution, UUID actor, UUID installation, byte[] publicKey) {
    Objects.requireNonNull(institution);
    Objects.requireNonNull(actor);
    Objects.requireNonNull(installation);
    if (publicKey == null || publicKey.length == 0 || publicKey.length > 128)
      throw new IllegalArgumentException("Clave publica invalida");
    byte[] nonce = new byte[32];
    random.nextBytes(nonce);
    UUID id = UUID.randomUUID();
    // La hora de la base es la autoridad tanto al emitir como al consumir.
    Instant now = db.queryForObject("SELECT clock_timestamp()", Instant.class);
    Instant expiresAt = Objects.requireNonNull(now).plus(LIFETIME);
    db.update("INSERT INTO app.inventory_installation_proof_challenges "
        + "(id, institution_id, actor_id, installation_id, public_key, nonce, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
        id, institution, actor, installation, publicKey, nonce, java.sql.Timestamp.from(expiresAt));
    return new Challenge(id, nonce.clone(), expiresAt);
  }

  /** Solo una firma valida y vigente consume el desafio; la operacion protegida futura debe compartir esta transaccion. */
  @Transactional
  public boolean consume(UUID id, UUID institution, UUID actor, UUID installation, byte[] signature) {
    List<Stored> rows = db.query("SELECT public_key, nonce, expires_at, consumed_at "
        + "FROM app.inventory_installation_proof_challenges WHERE id=? AND institution_id=? "
        + "AND actor_id=? AND installation_id=? FOR UPDATE", (rs, n) -> new Stored(
            rs.getBytes("public_key"), rs.getBytes("nonce"), rs.getTimestamp("expires_at").toInstant(),
            rs.getTimestamp("consumed_at") == null ? null : rs.getTimestamp("consumed_at").toInstant()),
        id, institution, actor, installation);
    if (rows.isEmpty()) return false;
    Stored challenge = rows.getFirst();
    // CURRENT_TIMESTAMP en PostgreSQL es el inicio de la transaccion, incluso tras esperar un bloqueo.
    Instant now = Objects.requireNonNull(db.queryForObject("SELECT clock_timestamp()", Instant.class));
    if (challenge.consumedAt() != null || !now.isBefore(challenge.expiresAt())
        || !InstallationProof.verify(challenge.key(), signature, institution, actor, installation, challenge.nonce())) return false;
    return db.update("UPDATE app.inventory_installation_proof_challenges SET consumed_at=? "
        + "WHERE id=? AND consumed_at IS NULL", java.sql.Timestamp.from(now), id) == 1;
  }
}
