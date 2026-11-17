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
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import org.springframework.transaction.support.TransactionTemplate;

/** Integracion H2 aislada: usa proxy transaccional y conexiones JDBC separadas. */
class HistoricalReviewIntegrationTest {
  private final UUID institution = UUID.randomUUID(), actor = UUID.randomUUID(), custodian = UUID.randomUUID();
  private final UUID assignment = UUID.randomUUID(), lot = UUID.randomUUID();
  private PermissionGuard guard;
  private PausingJdbcTemplate db;
  private TransactionTemplate writer;
  private InventoryService service;

  @BeforeEach
  void setUp() {
    var source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
        + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1;LOCK_TIMEOUT=10000", "sa", "");
    db = new PausingJdbcTemplate(source);
    var manager = new DataSourceTransactionManager(source);
    writer = new TransactionTemplate(manager);
    db.execute("CREATE SCHEMA app");
    db.execute("CREATE TABLE app.inventory_assignments (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, "
        + "vaccinator_id UUID, vial_count INT, received_vials INT, resolved_vials INT, status VARCHAR)");
    db.execute("CREATE TABLE app.inventory_receipts (id UUID PRIMARY KEY, institution_id UUID, assignment_id UUID, "
        + "lot_id UUID, vials INT, received_by UUID, received_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, difference_note VARCHAR)");
    db.execute("CREATE TABLE app.inventory_custody_events (id UUID PRIMARY KEY, institution_id UUID, assignment_id UUID, "
        + "lot_id UUID, vial_count INT, status VARCHAR, reported_by UUID, reported_at TIMESTAMP WITH TIME ZONE, "
        + "report_note VARCHAR, confirmed_by UUID, confirmed_at TIMESTAMP WITH TIME ZONE, confirmation_note VARCHAR)");
    db.update("INSERT INTO app.inventory_assignments VALUES (?, ?, ?, ?, 2, 0, 0, 'IN_TRANSIT')",
        assignment, institution, lot, custodian);
    guard = mock(PermissionGuard.class);
    var profile = mock(AuthorizedUser.class);
    var institutionProfile = mock(InstitutionEntity.class);
    when(institutionProfile.getId()).thenReturn(institution);
    when(profile.getInstitution()).thenReturn(institutionProfile);
    when(profile.getPermissions()).thenReturn(List.of("INVENTORY_READ"));
    when(guard.require(any(), any())).thenReturn(profile);
    var target = new InventoryService(db, guard, new DataScope());
    var factory = new ProxyFactory(target);
    factory.setProxyTargetClass(true);
    factory.addAdvice(new TransactionInterceptor(manager, new AnnotationTransactionAttributeSource()));
    service = (InventoryService) factory.getProxy();
  }

  @Test
  void reviewRequiresPermissionAndCannotReadAnotherInstitution() {
    UUID otherAssignment = UUID.randomUUID(), otherInstitution = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_assignments VALUES (?, ?, ?, ?, 2, 0, 0, 'IN_TRANSIT')",
        otherAssignment, otherInstitution, lot, custodian);
    assertThatThrownBy(() -> service.reviewHistoricalCustody(actor, institution, otherAssignment))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> service.reviewHistoricalCustody(actor, otherInstitution, otherAssignment))
        .isInstanceOf(ScopeViolationException.class);
    when(guard.require(actor, "INVENTORY_READ")).thenThrow(new AccessDeniedException("denegado"));
    assertThatThrownBy(() -> service.reviewHistoricalCustody(actor, institution, assignment))
        .isInstanceOf(AccessDeniedException.class);
  }

  @Test
  void singleStatementKeepsConsistentEvidenceEvenInsideReadCommittedTransaction() throws Exception {
    db.pauseAfterAssignment = true;
    UUID receipt = UUID.randomUUID();
    try (var executor = Executors.newSingleThreadExecutor()) {
      var future = executor.submit(() -> {
        var outer = new TransactionTemplate(writer.getTransactionManager());
        outer.setIsolationLevel(org.springframework.transaction.TransactionDefinition.ISOLATION_READ_COMMITTED);
        return outer.execute(s -> service.reviewHistoricalCustody(actor, institution, assignment));
      });
      try {
        assertThat(db.assignmentRead.await(10, TimeUnit.SECONDS)).isTrue();
        writer.executeWithoutResult(s -> {
          db.update("UPDATE app.inventory_assignments SET received_vials=2, status='RECEIVED' WHERE id=?", assignment);
          db.update("INSERT INTO app.inventory_receipts (id, institution_id, assignment_id, lot_id, vials, "
                  + "received_by, difference_note) VALUES (?, ?, ?, ?, 2, ?, '')",
              receipt, institution, assignment, lot, custodian);
        });
      } finally {
        db.continueReview.countDown();
      }
      var snapshot = future.get(10, TimeUnit.SECONDS);
      assertThat(snapshot.receivedVials()).isZero();
      assertThat(snapshot.status()).isEqualTo("IN_TRANSIT");
      assertThat(snapshot.receipts()).isEmpty();
      assertThat(snapshot.reviewReasons()).isEmpty();
      assertThat(db.reviewQueries.get()).isEqualTo(1);
    }
    db.pauseAfterAssignment = false;
    var latest = service.reviewHistoricalCustody(actor, institution, assignment);
    assertThat(latest.receivedVials()).isEqualTo(2);
    assertThat(latest.receipts()).extracting(InventoryService.HistoricalReceipt::id).containsExactly(receipt);
    assertThat(latest.reviewReasons()).isEmpty();
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts", Integer.class)).isEqualTo(1);
  }

  static class PausingJdbcTemplate extends JdbcTemplate {
    volatile boolean pauseAfterAssignment;
    final CountDownLatch assignmentRead = new CountDownLatch(1);
    final CountDownLatch continueReview = new CountDownLatch(1);
    final java.util.concurrent.atomic.AtomicInteger reviewQueries = new java.util.concurrent.atomic.AtomicInteger();

    PausingJdbcTemplate(DriverManagerDataSource source) { super(source); }

    @Override
    public <T> List<T> query(String sql, RowMapper<T> rowMapper, Object... args) {
      if (pauseAfterAssignment) reviewQueries.incrementAndGet();
      List<T> result = super.query(sql, rowMapper, args);
      if (pauseAfterAssignment && sql.stripLeading().startsWith("WITH selected AS (")) {
        assignmentRead.countDown();
        try {
          if (!continueReview.await(10, TimeUnit.SECONDS)) throw new AssertionError("Lectura pausada agotó tiempo");
        } catch (InterruptedException ex) {
          Thread.currentThread().interrupt();
          throw new IllegalStateException(ex);
        }
      }
      return result;
    }
  }
}
