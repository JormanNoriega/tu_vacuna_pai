package com.pai.api.inventory;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.identity.service.DataScope;
import com.pai.api.inventory.service.InventoryService;
import com.pai.api.inventory.service.CampaignService;
import com.pai.api.inventory.service.CustodyEventService;
import com.pai.api.inventory.service.InstallationReservationService;
import com.pai.api.inventory.security.InstallationChallengeService;
import com.pai.api.inventory.security.InstallationProof;
import com.pai.api.inventory.security.InstallationKeyService;
import com.pai.api.inventory.security.InstallationRecoveryService;
import com.pai.api.inventory.security.QuarantinedInstallationEventService;
import com.pai.api.shared.security.PermissionGuard;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
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

/** Opt-in: crea y elimina solo un lote de prueba identificado por UUID aleatorio. */
@EnabledIfEnvironmentVariable(named = "INVENTORY_RUN_PG_TEST", matches = "true")
class InventoryPostgresConcurrencyTest {
  @org.springframework.context.annotation.Configuration
  @org.springframework.transaction.annotation.EnableTransactionManagement
  static class TransactionConfig {}
  @Test
  void competingAssignmentsCannotOverdrawPostgresStock() throws Exception {
    Properties settings = new Properties();
    try (var reader = Files.newBufferedReader(Path.of(".env.local"))) { settings.load(reader); }
    String user = settings.getProperty("DB_USERNAME");
    String marker = System.getenv("INVENTORY_EXPECTED_DB_MARKER");
    assertThat(marker).isNotBlank();
    assertThat(user != null && user.endsWith("." + marker)).isTrue();
    var source = new DriverManagerDataSource(settings.getProperty("DB_URL"), user,
        settings.getProperty("DB_PASSWORD"));
    var db = new JdbcTemplate(source);
    var tx = new TransactionTemplate(new DataSourceTransactionManager(source));
    var target = db.queryForMap("SELECT u.id AS user_id, u.institution_id FROM app.users u "
        + "JOIN app.user_roles ur ON ur.user_id=u.id JOIN app.roles r ON r.id=ur.role_id "
        + "WHERE u.status='ACTIVE' AND r.code='VACCINATOR' LIMIT 1");
    UUID actor = (UUID) target.get("user_id");
    UUID institution = (UUID) target.get("institution_id");
    UUID vaccine = db.queryForObject("SELECT id FROM app.vaccines LIMIT 1", UUID.class);
    UUID lot = UUID.randomUUID();
    UUID campaign = UUID.randomUUID();
    UUID installationA = UUID.randomUUID();
    UUID installationB = UUID.randomUUID();
    UUID installationC = UUID.randomUUID();
    UUID installationD = UUID.randomUUID();
    UUID installationE = UUID.randomUUID();
    var guard = mock(PermissionGuard.class);
    var profile = mock(AuthorizedUser.class);
    var institutionProfile = mock(InstitutionEntity.class);
    when(institutionProfile.getId()).thenReturn(institution);
    when(profile.getInstitution()).thenReturn(institutionProfile);
    when(profile.getPermissions()).thenReturn(List.of("INVENTORY_WRITE", "INVENTORY_READ"));
    when(profile.getRoles()).thenReturn(List.of("VACCINATOR"));
    when(guard.require(any(), any())).thenReturn(profile);
    var service = new InventoryService(db, guard, new DataScope());
    var campaigns = new CampaignService(db, guard, new DataScope());
    var custody = new CustodyEventService(db, guard, new DataScope());
    var reservations = new InstallationReservationService(db, guard, new DataScope());
    Instant now = Instant.now();
    try {
      tx.executeWithoutResult(s -> campaigns.create(actor, institution, campaign,
          "PRUEBA AUTOMATICA", "Prueba", LocalDate.now(), LocalDate.now()));
      tx.executeWithoutResult(s -> service.createLot(actor, institution, lot, vaccine,
          "PRUEBA AUTOMATICA", lot.toString(), LocalDate.of(2099, 1, 1), 1));
      tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Prueba automatica"));
      var ready = new CountDownLatch(2);
      var start = new CountDownLatch(1);
      try (var executor = Executors.newFixedThreadPool(2)) {
        var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
          ready.countDown();
          if (!start.await(20, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
          try {
            tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(),
                UUID.randomUUID(), lot, actor, 7, now, "Prueba automatica", campaign));
            return true;
          } catch (IllegalArgumentException ex) {
            return false;
          }
        })).toList();
        assertThat(ready.await(20, TimeUnit.SECONDS)).isTrue();
        start.countDown();
        assertThat(List.of(tasks.get(0).get(45, TimeUnit.SECONDS), tasks.get(1).get(45, TimeUnit.SECONDS)))
            .containsExactlyInAnyOrder(true, false);
      }
      assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, lot)).isEqualTo(3);
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_assignments WHERE lot_id=?", Integer.class, lot)).isEqualTo(1);
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements WHERE lot_id=?", Integer.class, lot)).isEqualTo(2);
      UUID receivedId = db.queryForObject("SELECT id FROM app.inventory_assignments WHERE lot_id=?", UUID.class, lot);
      tx.executeWithoutResult(s -> campaigns.finish(actor, institution, campaign));
      assertThat(tx.execute(s -> service.receive(actor, institution, receivedId, 7)).status())
          .isEqualTo(com.pai.api.inventory.domain.VialTransfer.Status.RECEIVED);
      assertThat(tx.execute(s -> service.receive(actor, institution, receivedId, 7)).status())
          .isEqualTo(com.pai.api.inventory.domain.VialTransfer.Status.RECEIVED);
      assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, lot)).isEqualTo(3);
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements WHERE lot_id=?", Integer.class, lot)).isEqualTo(2);
      UUID returned = UUID.randomUUID();
      UUID held = UUID.randomUUID();
      tx.executeWithoutResult(s -> custody.report(actor, institution, returned, receivedId, 2, "RETURN", "Prueba"));
      assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, lot)).isEqualTo(3);
      tx.executeWithoutResult(s -> custody.confirmReturn(actor, institution, returned, "AVAILABLE", "Revision de prueba"));
      tx.executeWithoutResult(s -> custody.confirmReturn(actor, institution, returned, "AVAILABLE", "Revision de prueba"));
      tx.executeWithoutResult(s -> custody.report(actor, institution, held, receivedId, 1, "RETURN", "Prueba"));
      tx.executeWithoutResult(s -> custody.confirmReturn(actor, institution, held, "QUARANTINE", "Sin verificacion"));
      tx.executeWithoutResult(s -> custody.report(actor, institution, UUID.randomUUID(), receivedId, 1, "LOST", "Prueba"));
      assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, lot)).isEqualTo(5);
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements WHERE lot_id=?", Integer.class, lot)).isEqualTo(3);
      tx.executeWithoutResult(s -> reservations.register(actor, institution, installationA, "Prueba A"));
      tx.executeWithoutResult(s -> reservations.register(actor, institution, installationB, "Prueba B"));
      var challenges = new InstallationChallengeService(db);
      var keys = java.security.KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
      var challenge = tx.execute(s -> challenges.issue(institution, actor, installationA, keys.getPublic().getEncoded()));
      var signer = java.security.Signature.getInstance("Ed25519");
      signer.initSign(keys.getPrivate());
      signer.update(InstallationProof.message(institution, actor, installationA, challenge.nonce()));
      byte[] proof = signer.sign();
      var challengeStart = new CountDownLatch(1);
      try (var executor = Executors.newFixedThreadPool(2)) {
        var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
          challengeStart.await();
          return tx.execute(s -> challenges.consume(challenge.id(), institution, actor, installationA, proof));
        })).toList();
        challengeStart.countDown();
        assertThat(List.of(tasks.get(0).get(45, TimeUnit.SECONDS), tasks.get(1).get(45, TimeUnit.SECONDS)))
            .containsExactlyInAnyOrder(true, false);
      }
      System.out.println("PostgreSQL: desafio firmado, un solo consumo concurrente");
      tx.executeWithoutResult(s -> reservations.register(actor, institution, installationC, "Prueba carrera"));
      var keyService = new InstallationKeyService(db, guard, new DataScope(), challenges);
      byte[] key = keys.getPublic().getEncoded();
      var enrollment = tx.execute(s -> keyService.begin(actor, institution, installationC, key));
      signer.initSign(keys.getPrivate());
      signer.update(InstallationProof.message(institution, actor, installationC, enrollment.nonce()));
      byte[] enrollmentProof = signer.sign();
      var raceStart = new CountDownLatch(1);
      var raceReady = new CountDownLatch(2);
      try (var executor = Executors.newFixedThreadPool(2)) {
        var enroll = executor.submit(() -> {
          raceReady.countDown();
          if (!raceStart.await(20, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
          try {
            return tx.execute(s -> keyService.complete(actor, institution, installationC, enrollment.id(), key, enrollmentProof));
          } catch (IllegalArgumentException revoked) {
            if (!revoked.getMessage().contains("revocada")) throw revoked;
            return false;
          }
        });
        var revoke = executor.submit(() -> {
          raceReady.countDown();
          if (!raceStart.await(20, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
          tx.executeWithoutResult(s -> keyService.revoke(actor, institution, installationC, "Prueba carrera"));
          return true;
        });
        assertThat(raceReady.await(20, TimeUnit.SECONDS)).isTrue();
        raceStart.countDown();
        boolean enrolledBeforeRevoke = enroll.get(45, TimeUnit.SECONDS);
        assertThat(revoke.get(45, TimeUnit.SECONDS)).isTrue();
        System.out.println("PostgreSQL: carrera alta/revocacion, alta previa=" + enrolledBeforeRevoke + "; estado final revocado");
      }
      assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_keys WHERE installation_id=?", String.class, installationC)).isEqualTo("REVOKED");
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_installation_proof_challenges WHERE installation_id=? AND consumed_at IS NULL", Integer.class, installationC)).isZero();
      var startReservations = new CountDownLatch(1);
      try (var executor = Executors.newFixedThreadPool(2)) {
        var tasks = java.util.stream.Stream.of(installationA, installationB).map(device -> executor.submit(() -> {
          startReservations.await();
          try {
            tx.executeWithoutResult(s -> reservations.reserve(actor, institution, UUID.randomUUID(), receivedId, device, 2));
            return true;
          } catch (IllegalArgumentException ex) { return false; }
        })).toList();
        startReservations.countDown();
        assertThat(List.of(tasks.get(0).get(45, TimeUnit.SECONDS), tasks.get(1).get(45, TimeUnit.SECONDS)))
            .containsExactlyInAnyOrder(true, false);
      }
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_installation_reservations WHERE assignment_id=?", Integer.class, receivedId)).isEqualTo(1);
      assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, lot)).isEqualTo(5);
      UUID reservedInstallation = db.queryForObject("SELECT installation_id FROM app.inventory_installation_reservations WHERE assignment_id=?", UUID.class, receivedId);
      UUID reservedId = db.queryForObject("SELECT id FROM app.inventory_installation_reservations WHERE assignment_id=?", UUID.class, receivedId);
      var recovery = new InstallationRecoveryService(db, guard, new DataScope(), keyService);
      UUID caseId = UUID.randomUUID();
      assertThat((UUID) tx.execute(s -> recovery.open(actor, institution, reservedInstallation, caseId, "Prueba recuperacion"))).isEqualTo(caseId);
      assertThat((UUID) tx.execute(s -> recovery.open(actor, institution, reservedInstallation, caseId, "Prueba recuperacion"))).isEqualTo(caseId);
      assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_keys WHERE installation_id=?", String.class, reservedInstallation)).isEqualTo("REVOKED");
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_installation_recovery_cases WHERE id=? AND status='OPEN'", Integer.class, caseId)).isEqualTo(1);
      assertThat(db.queryForObject("SELECT vial_count FROM app.inventory_installation_reservations WHERE id=? AND installation_id=?", Integer.class, reservedId, reservedInstallation)).isEqualTo(2);
      UUID replacement = reservedInstallation.equals(installationA) ? installationB : installationA;
      var replacementChallenge = tx.execute(s -> keyService.begin(actor, institution, replacement, key));
      signer.initSign(keys.getPrivate());
      signer.update(InstallationProof.message(institution, actor, replacement, replacementChallenge.nonce()));
      byte[] replacementSignature = signer.sign();
      assertThat((Boolean) tx.execute(s -> keyService.complete(actor, institution, replacement,
          replacementChallenge.id(), key, replacementSignature))).isTrue();
      var linked = tx.execute(s -> recovery.linkReplacement(actor, institution, caseId, replacement, "Reemplazo verificado"));
      assertThat(linked.installationId()).isEqualTo(replacement);
      assertThat(db.queryForObject("SELECT vial_count FROM app.inventory_installation_reservations WHERE id=? AND installation_id=?", Integer.class, reservedId, reservedInstallation)).isEqualTo(2);
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_installation_reservations WHERE installation_id=?", Integer.class, replacement)).isZero();
      assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_recovery_cases WHERE id=?", String.class, caseId)).isEqualTo("OPEN");
      tx.executeWithoutResult(s -> keyService.revoke(actor, institution, replacement, "Prueba evento tardio"));
      var lateEvents = new QuarantinedInstallationEventService(db, guard, new DataScope());
      UUID lateId = UUID.randomUUID();
      byte[] latePayload = "evento sintetico".getBytes(java.nio.charset.StandardCharsets.UTF_8);
      signer.initSign(keys.getPrivate());
      signer.update(QuarantinedInstallationEventService.signingMessage(institution, actor, replacement, lateId, 1, latePayload));
      byte[] lateSignature = signer.sign();
      assertThat((UUID) tx.execute(s -> lateEvents.receive(actor, institution, replacement, lateId, 1, latePayload, lateSignature))).isEqualTo(lateId);
      assertThat((UUID) tx.execute(s -> lateEvents.receive(actor, institution, replacement, lateId, 1, latePayload, lateSignature))).isEqualTo(lateId);
      assertThat(db.queryForObject("SELECT status FROM app.inventory_quarantined_installation_events WHERE id=?", String.class, lateId)).isEqualTo("QUARANTINED");
      UUID lateCase = UUID.randomUUID(), lateReview = UUID.randomUUID();
      tx.executeWithoutResult(s -> recovery.open(actor, institution, replacement, lateCase, "Prueba revision evento"));
      tx.executeWithoutResult(s -> recovery.reviewEvent(actor, institution, lateCase, lateId, lateReview,
          "NEEDS_INVESTIGATION", "Fecha no comprobada"));
      UUID accessId = UUID.randomUUID();
      byte[] inspected = tx.execute(s -> recovery.readQuarantinedPayload(actor, institution, lateCase, lateId, accessId, "Revision institucional"));
      assertThat(inspected).containsExactly(latePayload);
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_quarantined_event_access_audit WHERE id=? AND accessed_by=?", Integer.class, accessId, actor)).isEqualTo(1);
      var identity = mock(IdentityService.class);
      when(identity.resolve(actor)).thenReturn(profile);
      when(profile.hasPermission("INVENTORY_WRITE")).thenReturn(true);
      when(profile.hasPermission(InstallationRecoveryService.QUARANTINE_PAYLOAD_READ)).thenReturn(false);
      var realGuard = new PermissionGuard(identity);
      var securedRecovery = new InstallationRecoveryService(db, realGuard, new DataScope(), keyService);
      try (var context = new org.springframework.context.annotation.AnnotationConfigApplicationContext()) {
        context.register(TransactionConfig.class);
        context.registerBean("transactionManager", org.springframework.transaction.PlatformTransactionManager.class,
            () -> new DataSourceTransactionManager(source));
        context.registerBean(InstallationRecoveryService.class, () -> securedRecovery);
        context.refresh();
        var secured = context.getBean(InstallationRecoveryService.class);
        UUID deniedId = UUID.randomUUID();
        org.assertj.core.api.Assertions.assertThatThrownBy(() -> secured.readQuarantinedPayload(actor, institution,
            lateCase, lateId, deniedId, "Prueba autorizacion"))
            .isInstanceOf(com.pai.api.shared.exceptions.PermissionDeniedException.class);
        assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_quarantined_event_access_audit WHERE id=?", Integer.class, deniedId)).isZero();
        when(profile.hasPermission(InstallationRecoveryService.QUARANTINE_PAYLOAD_READ)).thenReturn(true);
        UUID rollbackId = UUID.randomUUID();
        tx.executeWithoutResult(s -> {
          assertThat(secured.readQuarantinedPayload(actor, institution, lateCase, lateId, rollbackId, "Prueba rollback")).containsExactly(latePayload);
          s.setRollbackOnly();
        });
        assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_quarantined_event_access_audit WHERE id=?", Integer.class, rollbackId)).isEqualTo(1);
        UUID concurrentId = UUID.randomUUID();
        var startReads = new CountDownLatch(1);
        var readyReads = new CountDownLatch(2);
        try (var executor = Executors.newFixedThreadPool(2)) {
          var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
            readyReads.countDown();
            if (!startReads.await(20, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
            try {
              return java.util.Arrays.equals(latePayload, secured.readQuarantinedPayload(actor, institution,
                  lateCase, lateId, concurrentId, "Lectura simultanea"));
            } catch (org.springframework.dao.DataIntegrityViolationException duplicate) { return false; }
          })).toList();
          assertThat(readyReads.await(20, TimeUnit.SECONDS)).isTrue();
          startReads.countDown();
          assertThat(List.of(tasks.get(0).get(45, TimeUnit.SECONDS), tasks.get(1).get(45, TimeUnit.SECONDS)))
              .containsExactlyInAnyOrder(true, false);
        }
        assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_quarantined_event_access_audit WHERE id=?", Integer.class, concurrentId)).isEqualTo(1);
        System.out.println("PostgreSQL: permiso especifico exigido; auditoria sobrevive rollback; lectura duplicada concurrente rechazada");
      }
      assertThat(recovery.listCaseEvents(actor, institution, lateCase)).hasSize(1);
      assertThat(recovery.listEventReviews(actor, institution, lateCase)).hasSize(1);
      assertThat(db.queryForObject("SELECT status FROM app.inventory_quarantined_installation_events WHERE id=?", String.class, lateId)).isEqualTo("QUARANTINED");
      assertThat(recovery.assessClosure(actor, institution, lateCase).closureAllowed()).isFalse();
      assertThat(db.queryForObject("SELECT vial_count FROM app.inventory_installation_reservations WHERE id=? AND installation_id=?", Integer.class, reservedId, reservedInstallation)).isEqualTo(2);
      UUID reviewId = UUID.randomUUID();
      var review = tx.execute(s -> recovery.review(actor, institution, caseId, reviewId, reservedId, 1, "Conteo fisico de prueba"));
      assertThat(review.reservedVialsAtReview()).isEqualTo(2);
      assertThat(review.observedVials()).isEqualTo(1);
      List<InstallationRecoveryService.Review> reviews = tx.execute(s -> recovery.listReviews(actor, institution, caseId));
      assertThat(reviews).hasSize(1);
      assertThat(db.queryForObject("SELECT vial_count FROM app.inventory_installation_reservations WHERE id=? AND installation_id=?", Integer.class, reservedId, reservedInstallation)).isEqualTo(2);
      assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, lot)).isEqualTo(5);
      for (boolean reserveFirst : new boolean[] {true, false}) {
        UUID device = reserveFirst ? installationD : installationE;
        UUID newReservation = UUID.randomUUID();
        tx.executeWithoutResult(s -> reservations.register(actor, institution, device, "Prueba bloqueo reserva"));
        var firstLocked = new CountDownLatch(1);
        var releaseFirst = new CountDownLatch(1);
        var secondStarted = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
          var first = executor.submit(() -> tx.execute(s -> {
            if (reserveFirst) reservations.reserve(actor, institution, newReservation, receivedId, device, 1);
            else keyService.revoke(actor, institution, device, "Prueba de concurrencia");
            firstLocked.countDown();
            try { if (!releaseFirst.await(30, TimeUnit.SECONDS)) throw new AssertionError("Tiempo agotado"); }
            catch (InterruptedException e) { Thread.currentThread().interrupt(); throw new IllegalStateException(e); }
            return true;
          }));
          try {
            assertThat(firstLocked.await(30, TimeUnit.SECONDS)).isTrue();
            var second = executor.submit(() -> {
              secondStarted.countDown();
              try {
                return tx.execute(s -> {
                  if (reserveFirst) keyService.revoke(actor, institution, device, "Prueba de concurrencia");
                  else reservations.reserve(actor, institution, newReservation, receivedId, device, 1);
                  return true;
                });
              } catch (IllegalArgumentException e) {
                if (reserveFirst || !e.getMessage().contains("revocada")) throw e;
                return false;
              }
            });
            assertThat(secondStarted.await(20, TimeUnit.SECONDS)).isTrue();
            releaseFirst.countDown();
            assertThat(first.get(45, TimeUnit.SECONDS)).isTrue();
            assertThat(second.get(45, TimeUnit.SECONDS)).isEqualTo(reserveFirst);
          } finally { releaseFirst.countDown(); }
        }
        assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_keys WHERE installation_id=?", String.class, device)).isEqualTo("REVOKED");
        assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_installation_reservations WHERE id=? AND installation_id=?", Integer.class, newReservation, device))
            .isEqualTo(reserveFirst ? 1 : 0);
        if (reserveFirst) {
          assertThat(tx.execute(s -> reservations.reserve(actor, institution, newReservation, receivedId, device, 1)).id()).isEqualTo(newReservation);
        }
        System.out.println("PostgreSQL: " + (reserveFirst ? "reserva antes de revocacion conservada" : "revocacion antes de reserva rechazada"));
      }
      System.out.println("PostgreSQL: caso abierto, clave revocada, reserva y saldo intactos");
      System.out.println("PostgreSQL: dos reservas concurrentes, una aceptada; saldo deposito sin cambios");
    } finally {
      tx.executeWithoutResult(s -> {
        db.update("DELETE FROM app.inventory_quarantined_event_access_audit WHERE installation_id IN (?, ?, ?)", installationA, installationB, installationC);
        db.update("DELETE FROM app.inventory_quarantined_event_reviews WHERE installation_id IN (?, ?, ?)", installationA, installationB, installationC);
        db.update("DELETE FROM app.inventory_quarantined_installation_events WHERE installation_id IN (?, ?, ?)", installationA, installationB, installationC);
        db.update("DELETE FROM app.inventory_installation_recovery_replacements WHERE old_installation_id IN (?, ?, ?)", installationA, installationB, installationC);
        db.update("DELETE FROM app.inventory_installation_recovery_reviews WHERE installation_id IN (?, ?, ?)", installationA, installationB, installationC);
        db.update("DELETE FROM app.inventory_installation_reservations WHERE lot_id=?", lot);
        db.update("DELETE FROM app.inventory_installation_recovery_cases WHERE installation_id IN (?, ?, ?)", installationA, installationB, installationC);
        db.update("DELETE FROM app.inventory_installation_keys WHERE installation_id IN (?, ?)", installationD, installationE);
        db.update("DELETE FROM app.inventory_installation_keys WHERE installation_id IN (?, ?, ?)", installationA, installationB, installationC);
        db.update("DELETE FROM app.inventory_installation_proof_challenges WHERE installation_id IN (?, ?, ?)", installationA, installationB, installationC);
        db.update("DELETE FROM app.inventory_installations WHERE id IN (?, ?, ?)", installationA, installationB, installationC);
        db.update("DELETE FROM app.inventory_installations WHERE id IN (?, ?)", installationD, installationE);
        db.update("DELETE FROM app.inventory_custody_events WHERE lot_id=?", lot);
        db.update("DELETE FROM app.inventory_movements WHERE lot_id=?", lot);
        db.update("DELETE FROM app.inventory_assignments WHERE lot_id=?", lot);
        db.update("DELETE FROM app.inventory_lots WHERE id=?", lot);
        db.update("DELETE FROM app.inventory_campaign_participants WHERE campaign_id=?", campaign);
        db.update("DELETE FROM app.inventory_campaigns WHERE id=?", campaign);
      });
    }
  }
}
