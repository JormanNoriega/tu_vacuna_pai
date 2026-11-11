package com.pai.api.inventory;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.inventory.security.InstallationChallengeService;
import com.pai.api.inventory.security.InstallationKeyService;
import com.pai.api.inventory.security.InstallationProof;
import com.pai.api.shared.security.PermissionGuard;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.util.Properties;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.transaction.support.TransactionTemplate;

/** Opt-in; crea solo instalaciones temporales identificadas por UUID. */
@EnabledIfEnvironmentVariable(named = "INVENTORY_RUN_PG_TEST", matches = "true")
class InstallationKeyPostgresRaceTest {
  @Test void bothLockOrdersEndRevoked() throws Exception {
    var settings = new Properties();
    try (var reader = Files.newBufferedReader(Path.of(".env.local"))) { settings.load(reader); }
    String marker = System.getenv("INVENTORY_EXPECTED_DB_MARKER");
    String user = settings.getProperty("DB_USERNAME");
    assertThat(marker).isNotBlank();
    assertThat(user != null && user.endsWith("." + marker)).isTrue();
    var source = new DriverManagerDataSource(settings.getProperty("DB_URL"), user, settings.getProperty("DB_PASSWORD"));
    var db = new JdbcTemplate(source);
    var tx = new TransactionTemplate(new DataSourceTransactionManager(source));
    var target = db.queryForMap("SELECT u.id, u.institution_id FROM app.users u JOIN app.user_roles ur ON ur.user_id=u.id "
        + "JOIN app.roles r ON r.id=ur.role_id WHERE u.status='ACTIVE' AND r.code='VACCINATOR' LIMIT 1");
    UUID actor = (UUID) target.get("id"), institution = (UUID) target.get("institution_id");
    var guard = mock(PermissionGuard.class);
    var profile = mock(AuthorizedUser.class);
    var entity = mock(InstitutionEntity.class);
    when(entity.getId()).thenReturn(institution);
    when(profile.getInstitution()).thenReturn(entity);
    when(guard.require(any(), any())).thenReturn(profile);
    var service = new InstallationKeyService(db, guard, new DataScope(), new InstallationChallengeService(db));
    for (boolean enrollFirst : new boolean[] {true, false}) {
      UUID installation = UUID.randomUUID();
      try {
        db.update("INSERT INTO app.inventory_installations (id, institution_id, vaccinator_id, label) VALUES (?, ?, ?, ?)",
            installation, institution, actor, "Prueba carrera claves");
        var pair = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
        byte[] key = pair.getPublic().getEncoded();
        var challenge = tx.execute(s -> service.begin(actor, institution, installation, key));
        var signer = Signature.getInstance("Ed25519");
        signer.initSign(pair.getPrivate());
        signer.update(InstallationProof.message(institution, actor, installation, challenge.nonce()));
        byte[] signature = signer.sign();
        var locked = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        var contenderStarted = new CountDownLatch(1);
        try (var pool = Executors.newFixedThreadPool(2)) {
          var first = pool.submit(() -> tx.execute(s -> {
            boolean result = true;
            if (enrollFirst) result = service.complete(actor, institution, installation, challenge.id(), key, signature);
            else service.revoke(actor, institution, installation, "Prueba carrera");
            locked.countDown();
            try { if (!release.await(30, TimeUnit.SECONDS)) throw new AssertionError("Tiempo agotado"); }
            catch (InterruptedException e) { Thread.currentThread().interrupt(); throw new IllegalStateException(e); }
            return result;
          }));
          try {
            assertThat(locked.await(30, TimeUnit.SECONDS)).isTrue();
            var second = pool.submit(() -> {
              contenderStarted.countDown();
              try {
                return tx.execute(s -> {
                  if (enrollFirst) { service.revoke(actor, institution, installation, "Prueba carrera"); return true; }
                  return service.complete(actor, institution, installation, challenge.id(), key, signature);
                });
              } catch (IllegalArgumentException ex) {
                if (enrollFirst || !ex.getMessage().contains("revocada")) throw ex;
                return false;
              }
            });
            assertThat(contenderStarted.await(20, TimeUnit.SECONDS)).isTrue();
            release.countDown();
            assertThat(first.get(45, TimeUnit.SECONDS)).isTrue();
            assertThat(second.get(45, TimeUnit.SECONDS)).isEqualTo(enrollFirst);
          } finally { release.countDown(); }
        }
        assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_keys WHERE installation_id=?", String.class, installation)).isEqualTo("REVOKED");
        assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_installation_proof_challenges WHERE installation_id=? AND consumed_at IS NULL", Integer.class, installation)).isZero();
        System.out.println("PostgreSQL: " + (enrollFirst ? "alta antes de revocacion" : "revocacion antes de alta") + "; estado final REVOKED");
      } finally {
        tx.executeWithoutResult(s -> {
          db.update("DELETE FROM app.inventory_installation_keys WHERE installation_id=?", installation);
          db.update("DELETE FROM app.inventory_installation_proof_challenges WHERE installation_id=?", installation);
          db.update("DELETE FROM app.inventory_installations WHERE id=?", installation);
        });
      }
    }
  }
}
