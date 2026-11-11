package com.pai.api.inventory.security;

import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.security.PermissionGuard;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Buzon aislado y no clinico. Nunca usa fechas del dispositivo como prueba temporal. */
@Service
public class QuarantinedInstallationEventService {
  private static final byte[] DOMAIN = "tu-vacuna-late-event-v1\0".getBytes(StandardCharsets.US_ASCII);
  private final JdbcTemplate db;
  private final PermissionGuard guard;
  private final DataScope scope;
  public QuarantinedInstallationEventService(JdbcTemplate db, PermissionGuard guard, DataScope scope) {
    this.db = db; this.guard = guard; this.scope = scope;
  }

  private record Prior(UUID installation, UUID owner, long sequence, byte[] payload) {}

  /** Formato fijo: dominio, institucion, propietario, instalacion, evento, secuencia y SHA-256 del contenido. */
  public static byte[] signingMessage(UUID institution, UUID owner, UUID installation, UUID eventId,
      long sequence, byte[] payload) {
    if (sequence <= 0 || payload == null || payload.length == 0 || payload.length > 65536)
      throw new IllegalArgumentException("Evento invalido.");
    Objects.requireNonNull(institution); Objects.requireNonNull(owner);
    Objects.requireNonNull(installation); Objects.requireNonNull(eventId);
    try {
      byte[] digest = MessageDigest.getInstance("SHA-256").digest(payload);
      ByteBuffer out = ByteBuffer.allocate(DOMAIN.length + 4 * 16 + 8 + digest.length).put(DOMAIN);
      for (UUID id : new UUID[] {institution, owner, installation, eventId})
        out.putLong(id.getMostSignificantBits()).putLong(id.getLeastSignificantBits());
      return out.putLong(sequence).put(digest).array();
    } catch (GeneralSecurityException ex) { throw new IllegalStateException(ex); }
  }

  /** El actor autenticado debe ser el propietario; se permite clave revocada solo para cuarentena. */
  @Transactional
  public UUID receive(UUID actor, UUID institution, UUID installation, UUID eventId, long sequence,
      byte[] payload, byte[] signature) {
    UUID scoped = scope.resolveInstitutionId(guard.require(actor, "ATTENTION_CREATE"), Objects.requireNonNull(institution));
    byte[] message = signingMessage(scoped, actor, installation, eventId, sequence, payload);
    if (signature == null || signature.length != 64) throw new IllegalArgumentException("Firma invalida.");
    // Comparte el bloqueo de instalacion con revocacion y serializa reintentos y secuencias.
    var keys = db.query("SELECT k.public_key FROM app.inventory_installations i "
        + "JOIN app.inventory_installation_keys k ON k.installation_id=i.id AND k.institution_id=i.institution_id "
        + "WHERE i.institution_id=? AND i.id=? AND i.vaccinator_id=? AND k.vaccinator_id=i.vaccinator_id "
        + "AND k.status IN ('ACTIVE','REVOKED') AND k.public_key IS NOT NULL FOR UPDATE OF i",
        (rs, n) -> rs.getBytes(1), scoped, installation, actor);
    if (keys.isEmpty() || !verify(keys.getFirst(), message, signature))
      throw new IllegalArgumentException("Instalacion o firma invalida.");
    var previous = db.query("SELECT installation_id, vaccinator_id, sequence_number, payload "
        + "FROM app.inventory_quarantined_installation_events WHERE institution_id=? AND id=?",
        (rs, n) -> new Prior(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class), rs.getLong(3), rs.getBytes(4)), scoped, eventId);
    if (!previous.isEmpty()) {
      var prior = previous.getFirst();
      if (!prior.installation().equals(installation) || !prior.owner().equals(actor) || prior.sequence() != sequence
          || !Arrays.equals(prior.payload(), payload)) throw new IllegalArgumentException("Identificador de evento reutilizado.");
      return eventId;
    }
    Integer sequenceUsed = db.queryForObject("SELECT count(*) FROM app.inventory_quarantined_installation_events "
        + "WHERE institution_id=? AND installation_id=? AND sequence_number=?", Integer.class, scoped, installation, sequence);
    if (sequenceUsed == null || sequenceUsed != 0) throw new IllegalArgumentException("Secuencia de evento ya utilizada.");
    try {
      byte[] digest = MessageDigest.getInstance("SHA-256").digest(payload);
      db.update("INSERT INTO app.inventory_quarantined_installation_events (id, institution_id, installation_id, "
          + "vaccinator_id, sequence_number, payload, payload_sha256, signature, received_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
          eventId, scoped, installation, actor, sequence, payload, digest, signature, actor);
      return eventId;
    } catch (GeneralSecurityException ex) { throw new IllegalStateException(ex); }
  }

  private static boolean verify(byte[] key, byte[] message, byte[] signature) {
    try {
      var publicKey = KeyFactory.getInstance("Ed25519").generatePublic(new X509EncodedKeySpec(key));
      var verifier = Signature.getInstance("Ed25519");
      verifier.initVerify(publicKey); verifier.update(message);
      return verifier.verify(signature);
    } catch (GeneralSecurityException | IllegalArgumentException ex) { return false; }
  }
}
