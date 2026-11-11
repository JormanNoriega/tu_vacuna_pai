package com.pai.api.inventory.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.security.KeyPairGenerator;
import java.security.Signature;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.transaction.support.TransactionTemplate;

public class InstallationChallengeServiceTest {
  private JdbcTemplate db;
  private TransactionTemplate tx;
  private InstallationChallengeService service;
  private final UUID institution = UUID.randomUUID(), actor = UUID.randomUUID(), installation = UUID.randomUUID();

  public static java.time.OffsetDateTime clockTimestamp() { return java.time.OffsetDateTime.now(java.time.ZoneOffset.UTC); }

  @BeforeEach
  void setup() {
    var source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID() + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1", "sa", "");
    db = new JdbcTemplate(source);
    tx = new TransactionTemplate(new DataSourceTransactionManager(source));
    db.execute("CREATE SCHEMA app");
    db.execute("CREATE ALIAS clock_timestamp FOR 'com.pai.api.inventory.security.InstallationChallengeServiceTest.clockTimestamp'");
    db.execute("CREATE TABLE app.inventory_installation_proof_challenges (id UUID PRIMARY KEY, institution_id UUID, "
        + "actor_id UUID, installation_id UUID, public_key VARBINARY, nonce VARBINARY, "
        + "expires_at TIMESTAMP WITH TIME ZONE, consumed_at TIMESTAMP WITH TIME ZONE)");
    service = new InstallationChallengeService(db);
  }

  @Test
  void validProofIsSingleUseAndInvalidProofDoesNotConsume() throws Exception {
    var keys = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
    var challenge = tx.execute(s -> service.issue(institution, actor, installation, keys.getPublic().getEncoded()));
    assertThat(challenge.nonce()).hasSize(32);
    var signer = Signature.getInstance("Ed25519");
    signer.initSign(keys.getPrivate());
    signer.update(InstallationProof.message(institution, actor, installation, challenge.nonce()));
    byte[] proof = signer.sign();
    assertThat((Boolean) tx.execute(s -> service.consume(challenge.id(), institution, UUID.randomUUID(), installation, proof))).isFalse();
    assertThat((Boolean) tx.execute(s -> service.consume(challenge.id(), institution, actor, installation, new byte[64]))).isFalse();
    assertThat((Boolean) tx.execute(s -> service.consume(challenge.id(), institution, actor, installation, proof))).isTrue();
    assertThat((Boolean) tx.execute(s -> service.consume(challenge.id(), institution, actor, installation, proof))).isFalse();
  }

  @Test
  void expiredChallengeIsRejected() throws Exception {
    var keys = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
    var challenge = tx.execute(s -> service.issue(institution, actor, installation, keys.getPublic().getEncoded()));
    var signer = Signature.getInstance("Ed25519");
    signer.initSign(keys.getPrivate());
    signer.update(InstallationProof.message(institution, actor, installation, challenge.nonce()));
    byte[] proof = signer.sign();
    db.update("UPDATE app.inventory_installation_proof_challenges SET expires_at=? WHERE id=?", Instant.now().minusSeconds(1), challenge.id());
    assertThat((Boolean) tx.execute(s -> service.consume(challenge.id(), institution, actor, installation, proof))).isFalse();
  }

  @Test
  void concurrentConsumptionSucceedsOnlyOnce() throws Exception {
    var keys = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
    var challenge = tx.execute(s -> service.issue(institution, actor, installation, keys.getPublic().getEncoded()));
    var signer = Signature.getInstance("Ed25519");
    signer.initSign(keys.getPrivate());
    signer.update(InstallationProof.message(institution, actor, installation, challenge.nonce()));
    byte[] proof = signer.sign();
    var start = new CountDownLatch(1);
    try (var pool = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> pool.submit(() -> {
        start.await();
        return tx.execute(s -> service.consume(challenge.id(), institution, actor, installation, proof));
      })).toList();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
  }

  @Test
  void rollbackOfProtectedTransactionRestoresChallenge() throws Exception {
    var keys = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
    var challenge = tx.execute(s -> service.issue(institution, actor, installation, keys.getPublic().getEncoded()));
    var signer = Signature.getInstance("Ed25519");
    signer.initSign(keys.getPrivate());
    signer.update(InstallationProof.message(institution, actor, installation, challenge.nonce()));
    byte[] proof = signer.sign();
    tx.executeWithoutResult(status -> {
      assertThat(service.consume(challenge.id(), institution, actor, installation, proof)).isTrue();
      status.setRollbackOnly();
    });
    assertThat((Boolean) tx.execute(s -> service.consume(challenge.id(), institution, actor, installation, proof))).isTrue();
  }
}
