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

class CandidateCustodyLinkServiceTest {
  private final UUID institution = UUID.randomUUID(), actor = UUID.randomUUID(), custodian = UUID.randomUUID();
  private final UUID lot = UUID.randomUUID(), assignment = UUID.randomUUID(), custody = UUID.randomUUID();
  private JdbcTemplate db;
  private TransactionTemplate tx;
  private PermissionGuard guard;
  private CandidateCustodyLinkService service;

  @BeforeEach
  void setUp() {
    var source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
        + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1;LOCK_TIMEOUT=10000", "sa", "");
    db = new JdbcTemplate(source);
    tx = new TransactionTemplate(new DataSourceTransactionManager(source));
    db.execute("CREATE SCHEMA app");
    db.execute("CREATE TABLE app.institutions (id UUID PRIMARY KEY)");
    db.execute("CREATE TABLE app.users (id UUID PRIMARY KEY, institution_id UUID, status VARCHAR)");
    db.execute("CREATE TABLE app.inventory_lots (id UUID PRIMARY KEY, institution_id UUID NOT NULL, UNIQUE(institution_id,id))");
    db.execute("CREATE TABLE app.inventory_assignments (id UUID PRIMARY KEY, institution_id UUID NOT NULL, "
        + "lot_id UUID NOT NULL, vaccinator_id UUID NOT NULL, vial_count INT, received_vials INT, resolved_vials INT, status VARCHAR)");
    db.execute("CREATE TABLE app.inventory_receipts (id UUID PRIMARY KEY, institution_id UUID, assignment_id UUID, "
        + "lot_id UUID, received_by UUID, vials INT)");
    db.execute("CREATE TABLE app.inventory_custody_events (id UUID PRIMARY KEY, assignment_id UUID, status VARCHAR)");
    db.execute("CREATE TABLE app.inventory_movements (id UUID PRIMARY KEY)");
    new ResourceDatabasePopulator(new ClassPathResource("inventory/individual_custody_candidate.sql")).execute(source);
    db.update("INSERT INTO app.institutions VALUES (?)", institution);
    db.update("INSERT INTO app.users VALUES (?, ?, 'ACTIVE')", actor, institution);
    db.update("INSERT INTO app.users VALUES (?, ?, 'ACTIVE')", custodian, institution);
    db.update("INSERT INTO app.inventory_lots VALUES (?, ?)", lot, institution);
    db.update("INSERT INTO app.inventory_assignments VALUES (?, ?, ?, ?, 10, 8, 0, 'PARTIALLY_RECEIVED')",
        assignment, institution, lot, custodian);
    db.update("INSERT INTO app.inventory_receipts VALUES (?, ?, ?, ?, ?, 8)", UUID.randomUUID(), institution, assignment, lot, custodian);
    guard = mock(PermissionGuard.class);
    var profile = mock(AuthorizedUser.class);
    var institutionProfile = mock(InstitutionEntity.class);
    when(institutionProfile.getId()).thenReturn(institution);
    when(profile.getInstitution()).thenReturn(institutionProfile);
    when(profile.getPermissions()).thenReturn(List.of("INVENTORY_WRITE"));
    when(guard.require(any(), any())).thenReturn(profile);
    service = new CandidateCustodyLinkService(db, guard, new DataScope());
  }

  private UUID link(UUID cust, UUID transfer) {
    return tx.execute(s -> service.link(actor, institution, cust, transfer));
  }

  @Test
  void internalLinkCannotBeInvokedWithoutAnIssuedProof() {
    assertThat(CandidateReceiptOrchestrator.ReceiptProof.class.getDeclaredConstructors())
        .allSatisfy(c -> assertThat(java.lang.reflect.Modifier.isPrivate(c.getModifiers())).isTrue());
    assertThatThrownBy(() -> tx.execute(s -> service.linkFromReceipt(null)))
        .isInstanceOf(NullPointerException.class);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate", Integer.class)).isZero();
  }

  @Test
  void linksOnceWithoutChangingReceiptOrCreatingBalance() {
    assertThat(link(custody, assignment)).isEqualTo(custody);
    assertThat(link(custody, assignment)).isEqualTo(custody);
    assertThatThrownBy(() -> link(UUID.randomUUID(), assignment)).isInstanceOf(IllegalArgumentException.class);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate", Integer.class)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts", Integer.class)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT received_vials FROM app.inventory_assignments WHERE id=?", Integer.class, assignment))
        .isEqualTo(8);
  }

  @Test
  void requiresPermissionInstitutionAndActiveCustodian() {
    assertThatThrownBy(() -> tx.execute(s -> service.link(actor, UUID.randomUUID(), custody, assignment)))
        .isInstanceOf(ScopeViolationException.class);
    UUID foreign = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_assignments VALUES (?, ?, ?, ?, 10, 8, 0, 'PARTIALLY_RECEIVED')",
        foreign, UUID.randomUUID(), lot, custodian);
    assertThatThrownBy(() -> link(custody, foreign)).isInstanceOf(IllegalArgumentException.class);
    db.update("UPDATE app.users SET institution_id=? WHERE id=?", UUID.randomUUID(), custodian);
    assertThatThrownBy(() -> link(custody, assignment)).isInstanceOf(IllegalArgumentException.class);
    db.update("UPDATE app.users SET institution_id=?, status='INACTIVE' WHERE id=?", institution, custodian);
    assertThatThrownBy(() -> link(custody, assignment)).isInstanceOf(IllegalArgumentException.class);
    when(guard.require(actor, "INVENTORY_WRITE")).thenThrow(new AccessDeniedException("denegado"));
    assertThatThrownBy(() -> link(custody, assignment)).isInstanceOf(AccessDeniedException.class);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custodies_candidate", Integer.class)).isZero();
  }

  @Test
  void rejectsUnreceivedAndInconsistentEvidenceWithoutWrites() {
    db.update("UPDATE app.inventory_assignments SET received_vials=0,status='IN_TRANSIT' WHERE id=?", assignment);
    assertThatThrownBy(() -> link(custody, assignment)).isInstanceOf(IllegalArgumentException.class);
    db.update("UPDATE app.inventory_assignments SET received_vials=8,status='PARTIALLY_RECEIVED' WHERE id=?", assignment);
    db.update("UPDATE app.inventory_receipts SET vials=7 WHERE assignment_id=?", assignment);
    assertThatThrownBy(() -> link(custody, assignment)).isInstanceOf(IllegalArgumentException.class);
    db.update("UPDATE app.inventory_receipts SET vials=8,lot_id=? WHERE assignment_id=?", UUID.randomUUID(), assignment);
    assertThatThrownBy(() -> link(custody, assignment)).isInstanceOf(IllegalArgumentException.class);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate", Integer.class)).isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custodies_candidate", Integer.class)).isZero();
  }

  @Test
  void historicalFullReceiptIsLinkedWithoutSynthesizingReceipt() {
    db.update("DELETE FROM app.inventory_receipts WHERE assignment_id=?", assignment);
    db.update("UPDATE app.inventory_assignments SET received_vials=10,status='RECEIVED' WHERE id=?", assignment);
    assertThat(link(custody, assignment)).isEqualTo(custody);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts", Integer.class)).isZero();
  }

  @Test
  void concurrentIdenticalRequestsHaveOneLinkAndOneCustody() throws Exception {
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        start.await();
        return link(custody, assignment);
      })).toList();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactly(custody, custody);
    }
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custodies_candidate", Integer.class)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate", Integer.class)).isEqualTo(1);
  }

  @Test
  void concurrentConflictingCustodyIdsCannotLinkSameAssignmentTwice() throws Exception {
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        start.await();
        try { link(UUID.randomUUID(), assignment); return true; }
        catch (IllegalArgumentException e) { return false; }
      })).toList();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custodies_candidate", Integer.class)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate", Integer.class)).isEqualTo(1);
  }

  @Test
  void multipleDeliveriesShareCustodyAndPreserveTheirEvidence() {
    UUID secondAssignment = UUID.randomUUID(), secondReceipt = UUID.randomUUID(), event = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_assignments VALUES (?, ?, ?, ?, 4, 4, 0, 'RECEIVED')",
        secondAssignment, institution, lot, custodian);
    db.update("INSERT INTO app.inventory_receipts VALUES (?, ?, ?, ?, ?, 4)",
        secondReceipt, institution, secondAssignment, lot, custodian);
    db.update("INSERT INTO app.inventory_custody_events VALUES (?, ?, 'RETURN_PENDING')", event, assignment);
    assertThat(link(custody, assignment)).isEqualTo(custody);
    assertThat(link(custody, secondAssignment)).isEqualTo(custody);
    assertThat(link(custody, secondAssignment)).isEqualTo(custody);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custodies_candidate", Integer.class)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate WHERE custody_id=?",
        Integer.class, custody)).isEqualTo(2);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts", Integer.class)).isEqualTo(2);
    assertThat(db.queryForObject("SELECT id FROM app.inventory_custody_events WHERE assignment_id=?", UUID.class, assignment))
        .isEqualTo(event);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
  }

  @Test
  void complementaryReceiptAfterLinkPreservesSingleOriginAndBothReceipts() {
    UUID firstReceipt = db.queryForObject("SELECT id FROM app.inventory_receipts WHERE assignment_id=?",
        UUID.class, assignment);
    UUID complementary = UUID.randomUUID();
    assertThat(link(custody, assignment)).isEqualTo(custody);
    tx.executeWithoutResult(s -> {
      db.update("INSERT INTO app.inventory_receipts VALUES (?, ?, ?, ?, ?, 2)",
          complementary, institution, assignment, lot, custodian);
      db.update("UPDATE app.inventory_assignments SET received_vials=10, status='RECEIVED' WHERE id=?", assignment);
    });
    assertThat(link(custody, assignment)).isEqualTo(custody);
    assertThat(db.queryForList("SELECT id FROM app.inventory_receipts WHERE assignment_id=?", UUID.class, assignment))
        .containsExactlyInAnyOrder(firstReceipt, complementary);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate WHERE assignment_id=?",
        Integer.class, assignment)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
  }

  @Test
  void concurrentLinkAndComplementaryReceiptKeepConsistentEvidence() throws Exception {
    UUID complementary = UUID.randomUUID();
    var locked = new CountDownLatch(1);
    var release = new CountDownLatch(1);
    var linkStarted = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var receiving = executor.submit(() -> {
        tx.executeWithoutResult(s -> {
          db.queryForObject("SELECT id FROM app.inventory_assignments WHERE id=? FOR UPDATE", UUID.class, assignment);
          locked.countDown();
          try {
            if (!release.await(15, TimeUnit.SECONDS)) throw new AssertionError("Espera agotada");
          } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(e);
          }
          db.update("INSERT INTO app.inventory_receipts VALUES (?, ?, ?, ?, ?, 2)",
              complementary, institution, assignment, lot, custodian);
          db.update("UPDATE app.inventory_assignments SET received_vials=10,status='RECEIVED' WHERE id=?", assignment);
        });
        return true;
      });
      try {
        assertThat(locked.await(15, TimeUnit.SECONDS)).isTrue();
        var linking = executor.submit(() -> {
          linkStarted.countDown();
          return link(custody, assignment);
        });
        assertThat(linkStarted.await(15, TimeUnit.SECONDS)).isTrue();
        release.countDown();
        assertThat(receiving.get(15, TimeUnit.SECONDS)).isTrue();
        assertThat(linking.get(15, TimeUnit.SECONDS)).isEqualTo(custody);
      } finally {
        release.countDown();
      }
    }
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts WHERE assignment_id=?", Integer.class, assignment))
        .isEqualTo(2);
    assertThat(db.queryForObject("SELECT received_vials FROM app.inventory_assignments WHERE id=?", Integer.class, assignment))
        .isEqualTo(10);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate", Integer.class)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
  }

  @Test
  void concurrentDifferentDeliveriesWithSameCustodyAreLinkedExactlyOnce() throws Exception {
    UUID secondAssignment = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_assignments VALUES (?, ?, ?, ?, 4, 4, 0, 'RECEIVED')",
        secondAssignment, institution, lot, custodian);
    db.update("INSERT INTO app.inventory_receipts VALUES (?, ?, ?, ?, ?, 4)",
        UUID.randomUUID(), institution, secondAssignment, lot, custodian);
    var ready = new CountDownLatch(2);
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = List.of(assignment, secondAssignment).stream().map(id -> executor.submit(() -> {
        ready.countDown();
        if (!start.await(15, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        return link(custody, id);
      })).toList();
      assertThat(ready.await(15, TimeUnit.SECONDS)).isTrue();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactly(custody, custody);
    }
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custodies_candidate", Integer.class)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate", Integer.class)).isEqualTo(2);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
  }

  @Test
  void concurrentDifferentDeliveriesAndCustodyIdsDoNotCreateDuplicateCustody() throws Exception {
    UUID secondAssignment = UUID.randomUUID(), otherCustody = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_assignments VALUES (?, ?, ?, ?, 4, 4, 0, 'RECEIVED')",
        secondAssignment, institution, lot, custodian);
    db.update("INSERT INTO app.inventory_receipts VALUES (?, ?, ?, ?, ?, 4)",
        UUID.randomUUID(), institution, secondAssignment, lot, custodian);
    var ready = new CountDownLatch(2);
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        ready.countDown();
        if (!start.await(15, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        try {
          link(i == 0 ? custody : otherCustody, i == 0 ? assignment : secondAssignment);
          return true;
        } catch (IllegalArgumentException ex) { return false; }
      })).toList();
      assertThat(ready.await(15, TimeUnit.SECONDS)).isTrue();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custodies_candidate", Integer.class)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate", Integer.class)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts", Integer.class)).isEqualTo(2);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
  }
}
