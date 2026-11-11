package com.pai.api.inventory.security;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;
import java.util.Objects;
import java.util.UUID;

/** Primitiva aislada: verificar una firma no consume ni valida la vigencia de un desafio. */
public final class InstallationProof {
  private static final byte[] DOMAIN = "tu-vacuna-installation-proof-v1\0".getBytes(StandardCharsets.US_ASCII);
  private static final int NONCE_SIZE = 32;
  private static final int SIGNATURE_SIZE = 64;
  private static final int MAX_PUBLIC_KEY_SIZE = 128;

  private InstallationProof() {}

  /** Codificacion fija: dominio, institucion, usuario, instalacion y nonce del servidor. */
  public static byte[] message(UUID institution, UUID actor, UUID installation, byte[] nonce) {
    Objects.requireNonNull(institution);
    Objects.requireNonNull(actor);
    Objects.requireNonNull(installation);
    if (nonce == null || nonce.length != NONCE_SIZE) throw new IllegalArgumentException("Nonce invalido");
    ByteBuffer bytes = ByteBuffer.allocate(DOMAIN.length + 3 * 16 + NONCE_SIZE);
    bytes.put(DOMAIN);
    for (UUID id : new UUID[] {institution, actor, installation}) {
      bytes.putLong(id.getMostSignificantBits()).putLong(id.getLeastSignificantBits());
    }
    return bytes.put(nonce).array();
  }

  /** Clave publica Ed25519 en X.509 SubjectPublicKeyInfo, firma de 64 bytes. */
  public static boolean verify(byte[] publicKey, byte[] signature, UUID institution, UUID actor,
      UUID installation, byte[] nonce) {
    if (publicKey == null || publicKey.length == 0 || publicKey.length > MAX_PUBLIC_KEY_SIZE
        || signature == null || signature.length != SIGNATURE_SIZE) return false;
    try {
      var key = KeyFactory.getInstance("Ed25519").generatePublic(new X509EncodedKeySpec(publicKey));
      var verifier = Signature.getInstance("Ed25519");
      verifier.initVerify(key);
      verifier.update(message(institution, actor, installation, nonce));
      return verifier.verify(signature);
    } catch (GeneralSecurityException | IllegalArgumentException | NullPointerException ex) {
      return false;
    }
  }
}
