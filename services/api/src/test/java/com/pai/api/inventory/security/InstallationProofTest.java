package com.pai.api.inventory.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.security.KeyPairGenerator;
import java.security.SecureRandom;
import java.security.Signature;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class InstallationProofTest {
  @Test
  void proofBindsKeyNonceInstitutionActorAndInstallation() throws Exception {
    var keys = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
    var other = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
    UUID institution = UUID.randomUUID(), actor = UUID.randomUUID(), installation = UUID.randomUUID();
    byte[] nonce = new byte[32];
    new SecureRandom().nextBytes(nonce);
    var signer = Signature.getInstance("Ed25519");
    signer.initSign(keys.getPrivate());
    signer.update(InstallationProof.message(institution, actor, installation, nonce));
    byte[] signature = signer.sign();
    byte[] key = keys.getPublic().getEncoded();
    assertThat(InstallationProof.verify(key, signature, institution, actor, installation, nonce)).isTrue();
    assertThat(InstallationProof.verify(other.getPublic().getEncoded(), signature, institution, actor, installation, nonce)).isFalse();
    assertThat(InstallationProof.verify(key, signature, UUID.randomUUID(), actor, installation, nonce)).isFalse();
    assertThat(InstallationProof.verify(key, signature, institution, UUID.randomUUID(), installation, nonce)).isFalse();
    assertThat(InstallationProof.verify(key, signature, institution, actor, UUID.randomUUID(), nonce)).isFalse();
    byte[] altered = nonce.clone();
    altered[0] ^= 1;
    assertThat(InstallationProof.verify(key, signature, institution, actor, installation, altered)).isFalse();
    signature[0] ^= 1;
    assertThat(InstallationProof.verify(key, signature, institution, actor, installation, nonce)).isFalse();
  }

  @Test
  void malformedInputsFailClosed() {
    UUID id = UUID.randomUUID();
    assertThat(InstallationProof.verify(new byte[1000], new byte[64], id, id, id, new byte[32])).isFalse();
    assertThat(InstallationProof.verify(new byte[] {1}, new byte[64], id, id, id, new byte[32])).isFalse();
    assertThat(InstallationProof.verify(null, null, id, id, id, null)).isFalse();
  }
}
