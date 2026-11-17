package com.pai.api.inventory.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.exceptions.ScopeViolationException;
import com.pai.api.shared.security.PermissionGuard;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.transaction.support.TransactionTemplate;

class CandidateTransferFinalizationServiceTest {
  private final UUID institution = UUID.randomUUID(), admin = UUID.randomUUID(), vaccinator = UUID.randomUUID();
  private final UUID assignment = UUID.randomUUID(), lot = UUID.randomUUID(), operation = UUID.randomUUID();
  private JdbcTemplate db;
  private TransactionTemplate tx;
  private PermissionGuard guard;
  private CandidateTransferFinalizationService service;

  @BeforeEach
  void setUp() {
    var source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
        + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1;LOCK_TIMEOUT=10000", "sa", "");
    db = new JdbcTemplate(source);
    tx = new TransactionTemplate(new DataSourceTransactionManager(source));
    db.execute("CREATE SCHEMA app");
    db.execute("CREATE TABLE app.users (id UUID PRIMARY KEY)");
    db.execute("CREATE TABLE app.inventory_assignments (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, "
        + "vaccinator_id UUID, vial_count INT, received_vials INT, resolved_vials INT, status VARCHAR, "
        + "UNIQUE(institution_id,lot_id,id))");
    db.execute("CREATE TABLE app.inventory_receipts (id UUID PRIMARY KEY, institution_id UUID, assignment_id UUID, "
        + "lot_id UUID, received_by UUID, vials INT, difference_note VARCHAR)");
    db.execute("CREATE TABLE app.inventory_custody_events (id UUID PRIMARY KEY, institution_id UUID, assignment_id UUID, status VARCHAR)");
    db.execute("CREATE TABLE app.individual_custodies_candidate (id UUID PRIMARY KEY)");
    db.execute("CREATE TABLE app.inventory_difference_resolutions (id UUID PRIMARY KEY, assignment_id UUID, kind VARCHAR)");
    db.execute("CREATE TABLE app.inventory_movements (id UUID PRIMARY KEY)");
    new ResourceDatabasePopulator(new ClassPathResource("inventory/transfer_finalization_candidate.sql")).execute(source);
    db.update("INSERT INTO app.users VALUES (?)", admin);
    db.update("INSERT INTO app.users VALUES (?)", vaccinator);
    db.update("INSERT INTO app.inventory_assignments VALUES (?,?,?,?,10,10,0,'RECEIVED')",
        assignment, institution, lot, vaccinator);
    db.update("INSERT INTO app.inventory_receipts VALUES (?,?,?,?,?,10,'')",
        UUID.randomUUID(), institution, assignment, lot, vaccinator);
    guard = mock(PermissionGuard.class);
    var profile = mock(AuthorizedUser.class);
    var institutionProfile = mock(InstitutionEntity.class);
    when(institutionProfile.getId()).thenReturn(institution);
    when(profile.getInstitution()).thenReturn(institutionProfile);
    when(profile.getPermissions()).thenReturn(List.of("INVENTORY_WRITE", "ATTENTION_CREATE"));
    when(guard.require(any(), any())).thenReturn(profile);
    service = new CandidateTransferFinalizationService(db, guard, new DataScope());
  }

  private UUID finish(UUID actor, UUID id, boolean manual, String evidence) {
    return tx.execute(s -> service.finalizeTransfer(actor, institution, assignment, id, manual, evidence));
  }

  @Test
  void completeReceiptFinalizesOnceWithoutModifyingCustody() {
    UUID custody = UUID.randomUUID();
    db.update("INSERT INTO app.individual_custodies_candidate VALUES (?)", custody);
    assertThat(finish(vaccinator, operation, false, "")).isEqualTo(operation);
    assertThat(finish(vaccinator, operation, false, "")).isEqualTo(operation);
    assertThatThrownBy(() -> finish(vaccinator, UUID.randomUUID(), false, "")).isInstanceOf(IllegalArgumentException.class);
    assertThat(db.queryForObject("SELECT count(*) FROM app.transfer_finalizations_candidate", Integer.class)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custodies_candidate WHERE id=?", Integer.class, custody)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
    assertThat(db.queryForObject("SELECT received_vials FROM app.inventory_assignments WHERE id=?", Integer.class, assignment)).isEqualTo(10);
  }

  @Test
  void unresolvedDifferenceBlocksBothModes() {
    db.update("UPDATE app.inventory_assignments SET received_vials=8,status='PARTIALLY_RECEIVED' WHERE id=?", assignment);
    db.update("UPDATE app.inventory_receipts SET vials=8,difference_note='Faltante' WHERE assignment_id=?", assignment);
    assertThatThrownBy(() -> finish(vaccinator, operation, false, "")).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> finish(admin, operation, true, "Acta")).isInstanceOf(IllegalArgumentException.class);
    assertThat(db.queryForObject("SELECT count(*) FROM app.transfer_finalizations_candidate", Integer.class)).isZero();
  }

  @Test
  void correctionCanBeFinalizedByAdminWhilePhysicalFollowUpRemains() {
    UUID correction = UUID.randomUUID(), event = UUID.randomUUID();
    db.update("UPDATE app.inventory_assignments SET received_vials=8,resolved_vials=2,status='CLOSED_WITH_DIFFERENCE' WHERE id=?", assignment);
    db.update("UPDATE app.inventory_receipts SET vials=8,difference_note='Faltante' WHERE assignment_id=?", assignment);
    db.update("INSERT INTO app.inventory_difference_resolutions VALUES (?,?,'DISPATCH_CORRECTION')", correction, assignment);
    db.update("INSERT INTO app.inventory_custody_events VALUES (?,?,?,'INCIDENT_LOST')", event, institution, assignment);
    assertThatThrownBy(() -> finish(vaccinator, operation, false, "")).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> finish(admin, operation, true, " ")).isInstanceOf(IllegalArgumentException.class);
    assertThat(finish(admin, operation, true, "Acta de revisión; ubicación pendiente")).isEqualTo(operation);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_difference_resolutions WHERE id=?", Integer.class, correction)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT status FROM app.inventory_custody_events WHERE id=?", String.class, event)).isEqualTo("INCIDENT_LOST");
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
  }

  @Test
  void pendingReturnRemainsPendingAfterAdministrativeFinalization() {
    UUID event = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_custody_events VALUES (?,?,?,'RETURN_PENDING')",
        event, institution, assignment);
    assertThatThrownBy(() -> finish(vaccinator, operation, false, "")).isInstanceOf(IllegalArgumentException.class);
    assertThat(finish(admin, operation, true, "Devolución pendiente de recepción")).isEqualTo(operation);
    assertThat(db.queryForObject("SELECT status FROM app.inventory_custody_events WHERE id=?", String.class, event))
        .isEqualTo("RETURN_PENDING");
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
  }

  @Test
  void oldReceiptEvidenceRequiresExplicitAdministrativeReview() {
    db.update("DELETE FROM app.inventory_receipts WHERE assignment_id=?", assignment);
    assertThatThrownBy(() -> finish(vaccinator, operation, false, "")).isInstanceOf(IllegalArgumentException.class);
    assertThat(finish(admin, operation, true, "Revisión de entrega histórica")).isEqualTo(operation);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts", Integer.class)).isZero();
  }

  @Test
  void permissionScopeAndRecipientAreCheckedEvenForRetries() {
    assertThatThrownBy(() -> finish(admin, operation, false, "")).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.execute(s -> service.finalizeTransfer(admin, UUID.randomUUID(), assignment, operation, true, "Acta")))
        .isInstanceOf(ScopeViolationException.class);
    finish(admin, operation, true, "Acta");
    when(guard.require(admin, "INVENTORY_WRITE")).thenThrow(new AccessDeniedException("denegado"));
    assertThatThrownBy(() -> finish(admin, operation, true, "Acta")).isInstanceOf(AccessDeniedException.class);
  }

  @Test
  void concurrentIdenticalFinalizationsProduceOneRecord() throws Exception {
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        start.await();
        return finish(vaccinator, operation, false, "");
      })).toList();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactly(operation, operation);
    }
    assertThat(db.queryForObject("SELECT count(*) FROM app.transfer_finalizations_candidate", Integer.class)).isEqualTo(1);
  }

  @Test
  void concurrentContradictoryReviewsKeepOnlyOneAuditedDecision() throws Exception {
    var ready = new CountDownLatch(2);
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        ready.countDown();
        if (!start.await(15, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        try {
          finish(admin, operation, true, "Acta " + i);
          return true;
        } catch (IllegalArgumentException ex) { return false; }
      })).toList();
      assertThat(ready.await(15, TimeUnit.SECONDS)).isTrue();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
    assertThat(db.queryForObject("SELECT count(*) FROM app.transfer_finalizations_candidate", Integer.class)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT evidence FROM app.transfer_finalizations_candidate WHERE id=?",
        String.class, operation)).isIn("Acta 0", "Acta 1");
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
  }

  @Test
  void complementaryReceiptAndReviewCanCompleteWithoutLosingEvidence() throws Exception {
    UUID complementary = UUID.randomUUID(), custody = UUID.randomUUID();
    db.update("UPDATE app.inventory_assignments SET received_vials=8,status='PARTIALLY_RECEIVED' WHERE id=?", assignment);
    db.update("UPDATE app.inventory_receipts SET vials=8,difference_note='Faltante' WHERE assignment_id=?", assignment);
    db.update("INSERT INTO app.individual_custodies_candidate VALUES (?)", custody);
    var locked = new CountDownLatch(1);
    var startReview = new CountDownLatch(1);
    var release = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var reception = executor.submit(() -> {
        tx.executeWithoutResult(s -> {
          db.queryForObject("SELECT id FROM app.inventory_assignments WHERE id=? FOR UPDATE", UUID.class, assignment);
          locked.countDown();
          await(release);
          db.update("INSERT INTO app.inventory_receipts VALUES (?,?,?,?,?,2,'Llegaron')",
              complementary, institution, assignment, lot, vaccinator);
          db.update("UPDATE app.inventory_assignments SET received_vials=10,status='RECEIVED' WHERE id=?", assignment);
        });
        return true;
      });
      try {
        assertThat(locked.await(15, TimeUnit.SECONDS)).isTrue();
        var review = executor.submit(() -> {
          startReview.countDown();
          return finish(admin, operation, true, "Revisadas ambas recepciones");
        });
        assertThat(startReview.await(15, TimeUnit.SECONDS)).isTrue();
        release.countDown();
        assertThat(reception.get(15, TimeUnit.SECONDS)).isTrue();
        assertThat(review.get(15, TimeUnit.SECONDS)).isEqualTo(operation);
      } finally {
        release.countDown();
      }
    }
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts WHERE assignment_id=?", Integer.class, assignment))
        .isEqualTo(2);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custodies_candidate WHERE id=?", Integer.class, custody))
        .isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
  }

  @Test
  void pendingReturnRecordedConcurrentlyRequiresReviewAndRemainsPending() throws Exception {
    UUID event = UUID.randomUUID();
    var locked = new CountDownLatch(1);
    var closureStarted = new CountDownLatch(1);
    var release = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var report = executor.submit(() -> {
        tx.executeWithoutResult(s -> {
          db.queryForObject("SELECT id FROM app.inventory_assignments WHERE id=? FOR UPDATE", UUID.class, assignment);
          locked.countDown();
          await(release);
          db.update("INSERT INTO app.inventory_custody_events VALUES (?,?,?,'RETURN_PENDING')",
              event, institution, assignment);
        });
        return true;
      });
      try {
        assertThat(locked.await(15, TimeUnit.SECONDS)).isTrue();
        var automatic = executor.submit(() -> {
          closureStarted.countDown();
          try { finish(vaccinator, operation, false, ""); return true; }
          catch (IllegalArgumentException ex) { return false; }
        });
        assertThat(closureStarted.await(15, TimeUnit.SECONDS)).isTrue();
        release.countDown();
        assertThat(report.get(15, TimeUnit.SECONDS)).isTrue();
        assertThat(automatic.get(15, TimeUnit.SECONDS)).isFalse();
      } finally {
        release.countDown();
      }
    }
    assertThat(finish(admin, operation, true, "Devolución pendiente de recepción")).isEqualTo(operation);
    assertThat(db.queryForObject("SELECT status FROM app.inventory_custody_events WHERE id=?", String.class, event))
        .isEqualTo("RETURN_PENDING");
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
  }

  @Test
  void pendingReturnAfterFinalizationDoesNotDeleteClosureOrCreditDeposit() {
    finish(vaccinator, operation, false, "");
    UUID event = UUID.randomUUID();
    tx.executeWithoutResult(s -> {
      db.queryForObject("SELECT id FROM app.inventory_assignments WHERE id=? FOR UPDATE", UUID.class, assignment);
      db.update("INSERT INTO app.inventory_custody_events VALUES (?,?,?,'RETURN_PENDING')",
          event, institution, assignment);
    });
    assertThat(db.queryForObject("SELECT count(*) FROM app.transfer_finalizations_candidate WHERE id=?", Integer.class, operation))
        .isEqualTo(1);
    assertThat(db.queryForObject("SELECT status FROM app.inventory_custody_events WHERE id=?", String.class, event))
        .isEqualTo("RETURN_PENDING");
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
  }

  private static void await(CountDownLatch latch) {
    try {
      if (!latch.await(15, TimeUnit.SECONDS)) throw new AssertionError("Espera agotada");
    } catch (InterruptedException ex) {
      Thread.currentThread().interrupt();
      throw new IllegalStateException(ex);
    }
  }
}
