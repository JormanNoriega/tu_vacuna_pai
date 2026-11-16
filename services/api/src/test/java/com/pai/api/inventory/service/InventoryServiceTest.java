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
import java.time.Instant;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.transaction.support.TransactionTemplate;

/** Prueba el servicio con transacciones JDBC reales en H2; no sustituye PostgreSQL. */
class InventoryServiceTest {
  private JdbcTemplate db;
  private TransactionTemplate tx;
  private InventoryService service;
  private PermissionGuard guard;
  private CampaignService campaigns;
  private CustodyEventService custody;
  private InstallationReservationService reservations;
  private final UUID institution = UUID.randomUUID();
  private final UUID actor = UUID.randomUUID();
  private final UUID vaccinator = UUID.randomUUID();
  private final UUID lot = UUID.randomUUID();
  private final UUID vaccine = UUID.randomUUID();
  private final Instant now = Instant.parse("2026-01-01T12:00:00Z");

  private CandidateReceiptOrchestrator candidateOrchestrator() {
    db.execute("ALTER TABLE app.inventory_lots ADD CONSTRAINT uq_candidate_lot UNIQUE(institution_id,id)");
    db.execute("ALTER TABLE app.inventory_assignments ADD CONSTRAINT uq_candidate_assignment UNIQUE(institution_id,lot_id,id)");
    db.update("INSERT INTO app.users VALUES (?, ?, 'ACTIVE', 'Administrador')", actor, institution);
    var source = db.getDataSource();
    new org.springframework.jdbc.datasource.init.ResourceDatabasePopulator(
        new org.springframework.core.io.ClassPathResource("inventory/individual_custody_candidate.sql"),
        new org.springframework.core.io.ClassPathResource("inventory/transfer_finalization_candidate.sql")).execute(source);
    return new CandidateReceiptOrchestrator(db, service,
        new CandidateCustodyLinkService(db, guard, new DataScope()),
        new CandidateTransferFinalizationService(db, guard, new DataScope()), guard, new DataScope());
  }

  @BeforeEach
  void setUp() {
    var source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
        + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1;LOCK_TIMEOUT=10000", "sa", "");
    db = new JdbcTemplate(source);
    tx = new TransactionTemplate(new DataSourceTransactionManager(source));
    // Esquema minimo compatible con las consultas; V20 debe probarse aparte en PostgreSQL.
    db.execute("CREATE SCHEMA app");
    db.execute("CREATE TABLE app.institutions (id UUID PRIMARY KEY)");
    db.update("INSERT INTO app.institutions VALUES (?)", institution);
    db.execute("CREATE TABLE app.vaccines (id UUID PRIMARY KEY, name VARCHAR)");
    db.execute("CREATE TABLE app.users (id UUID PRIMARY KEY, institution_id UUID, status VARCHAR, full_name VARCHAR)");
    db.execute("CREATE TABLE app.roles (id UUID PRIMARY KEY, code VARCHAR)");
    db.execute("CREATE TABLE app.user_roles (user_id UUID, role_id UUID)");
    db.execute("CREATE TABLE app.inventory_lots (id UUID PRIMARY KEY, institution_id UUID, vaccine_id UUID, "
        + "manufacturer VARCHAR, lot_number VARCHAR, expires_on DATE, doses_per_vial INT, "
        + "available_vials INT DEFAULT 0 CHECK (available_vials >= 0), created_by UUID)");
    db.execute("CREATE TABLE app.inventory_assignments (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, "
        + "vaccinator_id UUID, vial_count INT, received_vials INT DEFAULT 0 NOT NULL, resolved_vials INT DEFAULT 0 NOT NULL, status VARCHAR, dispatched_by UUID, "
        + "dispatched_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, received_at TIMESTAMP WITH TIME ZONE, campaign_id UUID)");
    db.execute("CREATE TABLE app.inventory_campaigns (id UUID PRIMARY KEY, institution_id UUID, name VARCHAR, location VARCHAR, "
        + "starts_on DATE, ends_on DATE, status VARCHAR, created_by UUID, finished_by UUID, finished_at TIMESTAMP WITH TIME ZONE)");
    db.execute("CREATE TABLE app.inventory_campaign_participants (institution_id UUID, campaign_id UUID, vaccinator_id UUID, "
        + "added_by UUID, PRIMARY KEY(campaign_id, vaccinator_id))");
    db.execute("CREATE TABLE app.inventory_movements (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, "
        + "assignment_id UUID, kind VARCHAR, vial_count INT, occurred_at TIMESTAMP WITH TIME ZONE, "
        + "recorded_by UUID, note VARCHAR)");
    db.execute("CREATE TABLE app.inventory_lot_creation_operations (lot_id UUID PRIMARY KEY, institution_id UUID, "
        + "kind VARCHAR, movement_id UUID UNIQUE, created_by UUID)");
    db.execute("CREATE TABLE app.inventory_receipts (id UUID PRIMARY KEY, institution_id UUID, assignment_id UUID, "
        + "lot_id UUID, received_by UUID, vials INT, difference_note VARCHAR, received_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)");
    db.execute("CREATE TABLE app.inventory_difference_resolutions (id UUID PRIMARY KEY, institution_id UUID, "
        + "assignment_id UUID, lot_id UUID, kind VARCHAR, vial_count INT, note VARCHAR, recorded_by UUID, "
        + "recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)");
    db.execute("CREATE TABLE app.inventory_depot_regularizations (id UUID PRIMARY KEY, institution_id UUID, "
        + "resolution_id UUID, vial_count INT, note VARCHAR, recorded_by UUID, "
        + "recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)");
    db.execute("CREATE TABLE app.inventory_custody_events (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, "
        + "assignment_id UUID, vial_count INT, status VARCHAR, reported_by UUID, report_note VARCHAR, "
        + "reported_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, confirmed_by UUID, "
        + "confirmed_at TIMESTAMP WITH TIME ZONE, confirmation_note VARCHAR)");
    db.execute("CREATE TABLE app.inventory_installations (id UUID PRIMARY KEY, institution_id UUID, vaccinator_id UUID, "
        + "label VARCHAR, created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)");
    db.execute("CREATE TABLE app.inventory_installation_keys (installation_id UUID PRIMARY KEY, institution_id UUID, status VARCHAR)");
    db.execute("CREATE TABLE app.inventory_installation_reservations (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, "
        + "assignment_id UUID, vaccinator_id UUID, installation_id UUID, vial_count INT, created_by UUID, "
        + "created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)");
    UUID role = UUID.randomUUID();
    db.update("INSERT INTO app.vaccines VALUES (?, 'Vacuna de prueba')", vaccine);
    db.update("INSERT INTO app.users VALUES (?, ?, 'ACTIVE', 'Vacunador')", vaccinator, institution);
    db.update("INSERT INTO app.roles VALUES (?, 'VACCINATOR')", role);
    db.update("INSERT INTO app.user_roles VALUES (?, ?)", vaccinator, role);
    guard = mock(PermissionGuard.class);
    var actorProfile = mock(AuthorizedUser.class);
    var institutionProfile = mock(InstitutionEntity.class);
    when(institutionProfile.getId()).thenReturn(institution);
    when(actorProfile.getInstitution()).thenReturn(institutionProfile);
    when(actorProfile.getPermissions()).thenReturn(List.of("INVENTORY_READ", "INVENTORY_WRITE"));
    when(actorProfile.getRoles()).thenReturn(List.of("VACCINATOR"));
    when(guard.require(any(), any())).thenReturn(actorProfile);
    service = new InventoryService(db, guard, new DataScope(),
        Clock.fixed(Instant.parse("2026-01-02T04:59:59Z"), ZoneOffset.UTC));
    campaigns = new CampaignService(db, guard, new DataScope());
    custody = new CustodyEventService(db, guard, new DataScope());
    reservations = new InstallationReservationService(db, guard, new DataScope());
    tx.executeWithoutResult(s -> service.createLot(actor, institution, lot, vaccine,
        "Fabricante", "Lote-1", LocalDate.of(2028, 1, 1), 10));
  }

  @Test
  void candidateReceiptCustodyAndAutomaticFinalizationCommitAndRetryTogether() {
    var orchestrator = candidateOrchestrator();
    UUID assignment = UUID.randomUUID(), receipt = UUID.randomUUID(), custodyId = UUID.randomUUID(), closing = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 5, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 5, now, "Entrega"));
    org.mockito.Mockito.doThrow(new org.springframework.security.access.AccessDeniedException("denegado"))
        .when(guard).require(vaccinator, "INVENTORY_WRITE");
    var first = tx.execute(s -> orchestrator.receive(vaccinator, institution, assignment, receipt, 5, "", custodyId, closing));
    var replay = tx.execute(s -> orchestrator.receive(vaccinator, institution, assignment, receipt, 5, "", custodyId, closing));
    assertThat(first).isEqualTo(replay);
    assertThat(count("inventory_receipts")).isEqualTo(1);
    assertThat(count("individual_custody_origins_candidate")).isEqualTo(1);
    assertThat(count("transfer_finalizations_candidate")).isEqualTo(1);
    assertThat(db.queryForObject("SELECT linked_by FROM app.individual_custody_origins_candidate WHERE assignment_id=?",
        UUID.class, assignment)).isEqualTo(vaccinator);
    org.mockito.Mockito.verify(guard, org.mockito.Mockito.never()).require(vaccinator, "INVENTORY_WRITE");
    assertThat(count("inventory_movements")).isEqualTo(2);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isZero();
  }

  @Test
  void candidateReviewRetainsAutomaticFinalizationAndSubsequentRealPendingReturn() {
    var orchestrator = candidateOrchestrator();
    var reviewService = new CandidateCustodyReviewService(db, guard, new DataScope());
    UUID assignment = UUID.randomUUID(), receipt = UUID.randomUUID();
    UUID custodyId = UUID.randomUUID(), closing = UUID.randomUUID(), event = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 7, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment,
        lot, vaccinator, 5, now, "Entrega"));
    tx.executeWithoutResult(s -> orchestrator.receive(vaccinator, institution, assignment, receipt,
        5, "", custodyId, closing));
    int movementsBefore = count("inventory_movements");
    int depotBefore = service.listLots(actor, institution).getFirst().availableVials();
    assertThat(depotBefore).isEqualTo(2);

    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, event, assignment, 3, "RETURN", "Conteo físico"));
    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, event, assignment, 3, "RETURN", "Conteo físico"));
    var review = tx.execute(s -> reviewService.review(actor, institution, custodyId));

    assertThat(review.custodianId()).isEqualTo(vaccinator);
    assertThat(review.lotId()).isEqualTo(lot);
    assertThat(review.origins()).singleElement().satisfies(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(assignment);
      assertThat(origin.linkedBy()).isEqualTo(vaccinator);
      assertThat(origin.linkedAt()).isNotNull();
      assertThat(origin.receipts()).extracting(CandidateCustodyReviewService.Receipt::id).containsExactly(receipt);
      assertThat(origin.finalizations()).singleElement().satisfies(finalization -> {
        assertThat(finalization.id()).isEqualTo(closing);
        assertThat(finalization.kind()).isEqualTo("AUTOMATIC");
        assertThat(finalization.recordedBy()).isEqualTo(vaccinator);
      });
      assertThat(origin.events()).singleElement().satisfies(returned -> {
        assertThat(returned.id()).isEqualTo(event);
        assertThat(returned.status()).isEqualTo("RETURN_PENDING");
        assertThat(returned.vials()).isEqualTo(3);
        assertThat(returned.reportedBy()).isEqualTo(vaccinator);
        assertThat(returned.confirmedBy()).isNull();
        assertThat(returned.confirmedAt()).isNull();
      });
    });
    assertThat(count("individual_custody_origins_candidate")).isEqualTo(1);
    assertThat(count("transfer_finalizations_candidate")).isEqualTo(1);
    assertThat(count("inventory_custody_events")).isEqualTo(1);
    assertThat(count("inventory_movements")).isEqualTo(movementsBefore);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(depotBefore);
  }

  @Test
  void internalReceiptProofCannotBeReusedInSameOrLaterTransaction() {
    candidateOrchestrator(); // prepara únicamente el esquema candidato.
    var proof = new java.util.concurrent.atomic.AtomicReference<CandidateReceiptOrchestrator.ReceiptProof>();
    var linker = new CandidateCustodyLinkService(db, guard, new DataScope());
    var orchestrator = new CandidateReceiptOrchestrator(db, service, linker,
        new CandidateTransferFinalizationService(db, guard, new DataScope()), guard, new DataScope(), proof::set);
    UUID assignment = UUID.randomUUID(), receipt = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 5, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 5, now, "Entrega"));
    tx.executeWithoutResult(s -> {
      orchestrator.receive(vaccinator, institution, assignment, receipt, 5, "", UUID.randomUUID(), UUID.randomUUID());
      assertThatThrownBy(() -> linker.linkFromReceipt(proof.get())).isInstanceOf(IllegalStateException.class);
    });
    assertThatThrownBy(() -> linker.linkFromReceipt(proof.get())).isInstanceOf(IllegalStateException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> linker.linkFromReceipt(proof.get())))
        .isInstanceOf(IllegalStateException.class);
    assertThat(count("individual_custody_origins_candidate")).isEqualTo(1);
  }

  @Test
  void receiptProofFromRolledBackTransactionCannotBeUsedLater() {
    candidateOrchestrator();
    var proof = new java.util.concurrent.atomic.AtomicReference<CandidateReceiptOrchestrator.ReceiptProof>();
    var linker = new CandidateCustodyLinkService(db, guard, new DataScope());
    var orchestrator = new CandidateReceiptOrchestrator(db, service, linker,
        new CandidateTransferFinalizationService(db, guard, new DataScope()), guard, new DataScope(),
        p -> { proof.set(p); throw new IllegalStateException("Fallo de prueba"); });
    UUID assignment = UUID.randomUUID(), receipt = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 5, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 5, now, "Entrega"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> orchestrator.receive(vaccinator, institution,
        assignment, receipt, 5, "", UUID.randomUUID(), UUID.randomUUID())))
        .isInstanceOf(IllegalStateException.class).hasMessageContaining("Fallo de prueba");
    assertThat(proof.get()).isNotNull();
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> linker.linkFromReceipt(proof.get())))
        .isInstanceOf(IllegalStateException.class);
    assertThat(count("inventory_receipts")).isZero();
    assertThat(count("individual_custody_origins_candidate")).isZero();
  }

  @Test
  void internalProofCannotBeConsumedBySuspendedOuterTransactionInNewTransaction() {
    candidateOrchestrator();
    var linker = new CandidateCustodyLinkService(db, guard, new DataScope());
    var separate = new TransactionTemplate(tx.getTransactionManager());
    separate.setPropagationBehavior(org.springframework.transaction.TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    var orchestrator = new CandidateReceiptOrchestrator(db, service, linker,
        new CandidateTransferFinalizationService(db, guard, new DataScope()), guard, new DataScope(),
        proof -> assertThatThrownBy(() -> separate.executeWithoutResult(s -> linker.linkFromReceipt(proof)))
            .isInstanceOf(IllegalStateException.class));
    UUID assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 5, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 5, now, "Entrega"));
    tx.executeWithoutResult(s -> orchestrator.receive(vaccinator, institution, assignment,
        UUID.randomUUID(), 5, "", UUID.randomUUID(), UUID.randomUUID()));
    assertThat(count("inventory_receipts")).isEqualTo(1);
    assertThat(count("individual_custody_origins_candidate")).isEqualTo(1);
  }

  @Test
  void unrelatedVaccinatorCannotGenerateProofFromSomeoneElsesReceipt() {
    candidateOrchestrator();
    var proof = new java.util.concurrent.atomic.AtomicReference<CandidateReceiptOrchestrator.ReceiptProof>();
    var linker = new CandidateCustodyLinkService(db, guard, new DataScope());
    var orchestrator = new CandidateReceiptOrchestrator(db, service, linker,
        new CandidateTransferFinalizationService(db, guard, new DataScope()), guard, new DataScope(), proof::set);
    UUID assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 5, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 5, now, "Entrega"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> orchestrator.receive(actor, institution,
        assignment, UUID.randomUUID(), 5, "", UUID.randomUUID(), UUID.randomUUID())))
        .isInstanceOf(IllegalArgumentException.class);
    assertThat(proof.get()).isNull();
    assertThat(count("inventory_receipts")).isZero();
  }

  @Test
  void candidateReceiptRollsBackIfCustodyLinkFails() {
    var orchestrator = candidateOrchestrator();
    UUID assignment = UUID.randomUUID(), receipt = UUID.randomUUID(), custodyId = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 5, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 5, now, "Entrega"));
    var profile = guard.require(vaccinator, "ATTENTION_CREATE");
    when(guard.require(vaccinator, "ATTENTION_CREATE")).thenReturn(profile, profile)
        .thenThrow(new org.springframework.security.access.AccessDeniedException("denegado"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> orchestrator.receive(
        vaccinator, institution, assignment, receipt, 5, "", custodyId, UUID.randomUUID())))
        .isInstanceOf(org.springframework.security.access.AccessDeniedException.class);
    assertThat(count("inventory_receipts")).isZero();
    assertThat(count("individual_custody_origins_candidate")).isZero();
    assertThat(count("transfer_finalizations_candidate")).isZero();
    assertThat(db.queryForObject("SELECT received_vials FROM app.inventory_assignments WHERE id=?", Integer.class, assignment)).isZero();
    assertThat(db.queryForObject("SELECT status FROM app.inventory_assignments WHERE id=?", String.class, assignment)).isEqualTo("IN_TRANSIT");
  }

  @Test
  void candidateFinalizationFailureRollsBackReceiptAndCustodyLink() {
    var orchestrator = candidateOrchestrator();
    UUID firstAssignment = UUID.randomUUID(), secondAssignment = UUID.randomUUID();
    UUID custodyId = UUID.randomUUID(), closing = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), firstAssignment, lot, vaccinator, 5, now, "Entrega"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), secondAssignment, lot, vaccinator, 5, now, "Entrega"));
    tx.executeWithoutResult(s -> orchestrator.receive(vaccinator, institution, firstAssignment, UUID.randomUUID(), 5, "", custodyId, closing));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> orchestrator.receive(
        vaccinator, institution, secondAssignment, UUID.randomUUID(), 5, "", custodyId, closing)))
        .isInstanceOf(DataIntegrityViolationException.class);
    assertThat(db.queryForObject("SELECT received_vials FROM app.inventory_assignments WHERE id=?",
        Integer.class, secondAssignment)).isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts WHERE assignment_id=?",
        Integer.class, secondAssignment)).isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate WHERE assignment_id=?",
        Integer.class, secondAssignment)).isZero();
    assertThat(count("transfer_finalizations_candidate")).isEqualTo(1);
  }

  @Test
  void candidatePartialThenComplementaryReceiptDoesNotAutomaticallyFinalize() {
    var orchestrator = candidateOrchestrator();
    UUID assignment = UUID.randomUUID(), custodyId = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 5, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 5, now, "Entrega"));
    tx.executeWithoutResult(s -> orchestrator.receive(vaccinator, institution, assignment, UUID.randomUUID(), 3, "Faltan dos", custodyId, UUID.randomUUID()));
    tx.executeWithoutResult(s -> orchestrator.receive(vaccinator, institution, assignment, UUID.randomUUID(), 2, "", custodyId, UUID.randomUUID()));
    assertThat(count("inventory_receipts")).isEqualTo(2);
    assertThat(count("individual_custody_origins_candidate")).isEqualTo(1);
    assertThat(count("transfer_finalizations_candidate")).isZero();
  }

  @Test
  void concurrentCandidateIdenticalReceiptIsAppliedOnce() throws Exception {
    var orchestrator = candidateOrchestrator();
    UUID assignment = UUID.randomUUID(), receipt = UUID.randomUUID(), custodyId = UUID.randomUUID(), closing = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 5, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 5, now, "Entrega"));
    var ready = new CountDownLatch(2);
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        ready.countDown();
        if (!start.await(15, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        return tx.execute(s -> orchestrator.receive(vaccinator, institution, assignment, receipt, 5, "", custodyId, closing));
      })).toList();
      assertThat(ready.await(15, TimeUnit.SECONDS)).isTrue();
      start.countDown();
      assertThat(tasks.get(0).get(15, TimeUnit.SECONDS)).isEqualTo(tasks.get(1).get(15, TimeUnit.SECONDS));
    }
    assertThat(count("inventory_receipts")).isEqualTo(1);
    assertThat(count("individual_custody_origins_candidate")).isEqualTo(1);
    assertThat(count("transfer_finalizations_candidate")).isEqualTo(1);
    assertThat(count("inventory_movements")).isEqualTo(2);
  }

  @Test
  void expiredLotCannotBeDispatchedButRemainsVisibleAndCanReceiveEntries() {
    db.update("UPDATE app.inventory_lots SET expires_on = ? WHERE id = ?", LocalDate.of(2025, 12, 31), lot);
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 3, now, "Conteo"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.dispatch(actor, institution,
        UUID.randomUUID(), UUID.randomUUID(), lot, vaccinator, 1, now, "Entrega")))
        .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("vencido");
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(3);
    assertThat(count("inventory_assignments")).isZero();
    assertThat(count("inventory_movements")).isEqualTo(1);
  }

  @Test
  void expiryDayIsInclusiveUsingColombiaTimeNotClientTime() {
    db.update("UPDATE app.inventory_lots SET expires_on = ? WHERE id = ?", LocalDate.of(2026, 1, 1), lot);
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 2, now, "Conteo"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), UUID.randomUUID(),
        lot, vaccinator, 1, Instant.parse("2030-01-01T00:00:00Z"), "Entrega"));
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(1);
    var afterMidnightBogota = new InventoryService(db, guard, new DataScope(),
        Clock.fixed(Instant.parse("2026-01-02T05:00:00Z"), ZoneOffset.UTC));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> afterMidnightBogota.dispatch(actor, institution,
        UUID.randomUUID(), UUID.randomUUID(), lot, vaccinator, 1, now, "Entrega")))
        .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("vencido");
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(1);
  }

  @Test
  void receivedStockCanBeReturnedAfterExpiryWithoutAllowingNewDispatch() {
    UUID assignment = receivedAssignment(8);
    UUID event = UUID.randomUUID();
    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, event, assignment, 3, "RETURN", "Conteo físico"));
    db.update("UPDATE app.inventory_lots SET expires_on = ? WHERE id = ?", LocalDate.of(2025, 12, 31), lot);
    tx.executeWithoutResult(s -> custody.confirmReturn(actor, institution, event, "AVAILABLE", "Recepción física"));
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(5);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.dispatch(actor, institution,
        UUID.randomUUID(), UUID.randomUUID(), lot, vaccinator, 1, now, "Entrega")))
        .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("vencido");
  }

  @Test
  void pendingFollowUpsSeparateUnregularizedCorrectionFromUnconfirmedReturn() {
    UUID assignment = UUID.randomUUID(), correction = UUID.randomUUID(), event = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 10, now, "Entrega"));
    tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, assignment, UUID.randomUUID(), 8, "Diferencia"));
    tx.executeWithoutResult(s -> service.resolveDifference(actor, institution, assignment, correction, "DISPATCH_CORRECTION", 2, "Acta"));
    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, event, assignment, 3, "RETURN", "Conteo"));
    int movementCount = count("inventory_movements");
    var pending = service.listPendingFollowUps(actor, institution);
    assertThat(pending).hasSize(2);
    assertThat(pending).anySatisfy(item -> {
      assertThat(item.id()).isEqualTo(correction);
      assertThat(item.kind()).isEqualTo("DISPATCH_CORRECTION");
      assertThat(item.originalVials()).isEqualTo(2);
      assertThat(item.regularizedVials()).isZero();
      assertThat(item.pendingVials()).isEqualTo(2);
    });
    assertThat(pending).anySatisfy(item -> {
      assertThat(item.id()).isEqualTo(event);
      assertThat(item.kind()).isEqualTo("RETURN_PENDING");
      assertThat(item.pendingVials()).isEqualTo(3);
    });
    assertThat(count("inventory_movements")).isEqualTo(movementCount);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isZero();
    tx.executeWithoutResult(s -> service.regularizeDepot(actor, institution, correction, UUID.randomUUID(), 1, "Conteo", true));
    assertThat(service.listPendingFollowUps(actor, institution)).anySatisfy(item -> {
      assertThat(item.id()).isEqualTo(correction);
      assertThat(item.pendingVials()).isEqualTo(1);
    });
    tx.executeWithoutResult(s -> custody.confirmReturn(actor, institution, event, "QUARANTINE", "Revisión pendiente"));
    tx.executeWithoutResult(s -> service.regularizeDepot(actor, institution, correction, UUID.randomUUID(), 1, "Conteo", true));
    assertThat(service.listPendingFollowUps(actor, institution)).isEmpty();
    assertThatThrownBy(() -> service.listPendingFollowUps(actor, UUID.randomUUID())).isInstanceOf(ScopeViolationException.class);
    when(guard.require(actor, "INVENTORY_READ"))
        .thenThrow(new org.springframework.security.access.AccessDeniedException("denegado"));
    assertThatThrownBy(() -> service.listPendingFollowUps(actor, institution))
        .isInstanceOf(org.springframework.security.access.AccessDeniedException.class);
  }

  @Test
  void pendingFollowUpsExcludeOtherInstitutions() {
    UUID otherInstitution = UUID.randomUUID(), otherLot = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_lots (id,institution_id,vaccine_id,manufacturer,lot_number,expires_on,doses_per_vial,created_by) "
        + "VALUES (?,?,?,'F','OTRO',?,10,?)", otherLot, otherInstitution, vaccine, LocalDate.of(2028, 1, 1), actor);
    db.update("INSERT INTO app.inventory_difference_resolutions (id,institution_id,assignment_id,lot_id,kind,vial_count,note,recorded_by) "
        + "VALUES (?,?,?,?,'DISPATCH_CORRECTION',1,'Acta',?)", UUID.randomUUID(), otherInstitution, UUID.randomUUID(), otherLot, actor);
    assertThat(service.listPendingFollowUps(actor, institution)).isEmpty();
  }

  @Test
  void historicalReviewPreservesReferencesWithoutWritingOrAssigningEventsToReceipts() {
    UUID assignment = UUID.randomUUID(), receipt1 = UUID.randomUUID(), receipt2 = UUID.randomUUID();
    UUID event = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment,
        lot, vaccinator, 10, now, "Entrega"));
    tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, assignment, receipt1, 8, "Faltan dos"));
    tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, assignment, receipt2, 2, "Llegaron"));
    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, event, assignment, 3, "RETURN", "Conteo físico"));
    int movementsBefore = count("inventory_movements");
    var review = tx.execute(s -> service.reviewHistoricalCustody(actor, institution, assignment));
    assertThat(review.assignmentId()).isEqualTo(assignment);
    assertThat(review.custodianId()).isEqualTo(vaccinator);
    assertThat(review.receipts()).extracting(InventoryService.HistoricalReceipt::id).containsExactlyInAnyOrder(receipt1, receipt2);
    assertThat(review.events()).singleElement().satisfies(item -> {
      assertThat(item.id()).isEqualTo(event);
      assertThat(item.status()).isEqualTo("RETURN_PENDING");
      assertThat(item.reportedBy()).isEqualTo(vaccinator);
      assertThat(item.reportNote()).isEqualTo("Conteo físico");
      assertThat(item.confirmedAt()).isNull();
    });
    assertThat(review.reviewReasons()).isEmpty();
    assertThat(review.assignmentOnlyReceiptEvidence()).isFalse();
    assertThat(count("inventory_movements")).isEqualTo(movementsBefore);
    assertThat(count("inventory_receipts")).isEqualTo(2);
    assertThat(count("inventory_custody_events")).isEqualTo(1);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isZero();
    assertThatThrownBy(() -> service.reviewHistoricalCustody(actor, UUID.randomUUID(), assignment))
        .isInstanceOf(ScopeViolationException.class);
    assertThatThrownBy(() -> service.reviewHistoricalCustody(actor, institution, UUID.randomUUID()))
        .isInstanceOf(IllegalArgumentException.class);
    when(guard.require(actor, "INVENTORY_READ"))
        .thenThrow(new org.springframework.security.access.AccessDeniedException("denegado"));
    assertThatThrownBy(() -> service.reviewHistoricalCustody(actor, institution, assignment))
        .isInstanceOf(org.springframework.security.access.AccessDeniedException.class);
  }

  @Test
  void historicalReviewUsesAssignmentOnlyEvidenceWithoutCreatingReceipt() {
    UUID assignment = receivedAssignment(8);
    var result = tx.execute(s -> service.reviewHistoricalCustody(actor, institution, assignment));
    assertThat(result.assignmentOnlyReceiptEvidence()).isTrue();
    assertThat(result.receipts()).isEmpty();
    assertThat(result.receivedVials()).isEqualTo(8);
    assertThat(result.reviewReasons()).isEmpty();
    assertThat(count("inventory_receipts")).isZero();
  }

  @Test
  void historicalReviewReportsMismatchedReceiptWithoutFixingData() {
    UUID assignment = receivedAssignment(8);
    db.update("INSERT INTO app.inventory_receipts (id, institution_id, assignment_id, lot_id, received_by, vials, difference_note) "
        + "VALUES (?, ?, ?, ?, ?, ?, ?)", UUID.randomUUID(), institution, assignment, lot, vaccinator, 7, "Prueba");
    var result = tx.execute(s -> service.reviewHistoricalCustody(actor, institution, assignment));
    assertThat(result.reviewReasons()).contains("RECEIPT_TOTAL_MISMATCH");
    assertThat(result.assignmentOnlyReceiptEvidence()).isFalse();
    assertThat(count("inventory_receipts")).isEqualTo(1);
  }

  @Test
  void historicalReviewDoesNotReturnAnAssignmentFromAnotherInstitution() {
    UUID otherInstitution = UUID.randomUUID(), otherAssignment = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_assignments (id, institution_id, lot_id, vaccinator_id, vial_count, status, dispatched_by) "
        + "VALUES (?, ?, ?, ?, ?, 'IN_TRANSIT', ?)", otherAssignment, otherInstitution, lot, vaccinator, 1, actor);
    assertThatThrownBy(() -> service.reviewHistoricalCustody(actor, institution, otherAssignment))
        .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("no encontrada");
  }

  @Test
  void custodyReportRetryIsIdempotentEvenAfterReturnConfirmation() {
    UUID assignment = receivedAssignment(8);
    UUID event = UUID.randomUUID();
    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, event, assignment, 8, "RETURN", "Conteo"));
    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, event, assignment, 8, "RETURN", " Conteo "));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> custody.report(vaccinator, institution,
        event, assignment, 7, "RETURN", "Conteo"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> custody.report(vaccinator, institution,
        event, assignment, 8, "LOST", "Conteo"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> custody.report(actor, institution,
        event, assignment, 8, "RETURN", "Conteo"))).isInstanceOf(IllegalArgumentException.class);
    tx.executeWithoutResult(s -> custody.confirmReturn(actor, institution, event, "AVAILABLE", "Revisión"));
    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, event, assignment, 8, "RETURN", "Conteo"));
    assertThat(count("inventory_custody_events")).isEqualTo(1);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(10);
    assertThat(db.queryForObject("SELECT COUNT(*) FROM app.inventory_movements WHERE kind='RETURN'", Integer.class))
        .isEqualTo(1);
  }

  @Test
  void concurrentIdenticalCustodyReportsAreRecordedOnce() throws Exception {
    UUID assignment = receivedAssignment(8);
    UUID event = UUID.randomUUID();
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        start.await();
        tx.executeWithoutResult(s -> custody.report(vaccinator, institution, event, assignment, 8, "LOST", "Acta"));
        return true;
      })).toList();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactly(true, true);
    }
    assertThat(count("inventory_custody_events")).isEqualTo(1);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(2);
  }

  @Test
  void partialAndComplementaryReceiptsAreIdempotentAndOnlyReceivedVialsCanBeDeclared() {
    UUID assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Conteo"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment,
        lot, vaccinator, 10, now, "Entrega"));
    UUID receipt = UUID.randomUUID();
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution,
        assignment, receipt, 8, ""))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.receivePartial(actor, institution,
        assignment, receipt, 8, "Faltante"))).isInstanceOf(IllegalArgumentException.class);
    var partial = tx.execute(s -> service.receivePartial(vaccinator, institution, assignment, receipt, 8, "Faltante"));
    assertThat(partial.receivedVials()).isEqualTo(8);
    assertThat(partial.pendingDifference()).isEqualTo(2);
    InventoryService.ReceiptResult partialRetry =
        tx.execute(s -> service.receivePartial(vaccinator, institution, assignment, receipt, 8, "Faltante"));
    assertThat(partialRetry).isEqualTo(partial);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution,
        assignment, receipt, 7, "Faltante"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.receive(vaccinator, institution, assignment, 10)))
        .isInstanceOf(IllegalStateException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> custody.report(vaccinator, institution,
        UUID.randomUUID(), assignment, 9, "RETURN", "Conteo"))).isInstanceOf(IllegalArgumentException.class);
    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, UUID.randomUUID(), assignment, 8, "RETURN", "Conteo"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution,
        assignment, UUID.randomUUID(), 3, ""))).isInstanceOf(IllegalArgumentException.class);
    UUID finalReceipt = UUID.randomUUID();
    var complete = tx.execute(s -> service.receivePartial(vaccinator, institution, assignment, finalReceipt, 2, ""));
    assertThat(complete.receivedVials()).isEqualTo(10);
    assertThat(complete.pendingDifference()).isZero();
    assertThat(complete.status()).isEqualTo("RECEIVED");
    InventoryService.ReceiptResult completeRetry =
        tx.execute(s -> service.receivePartial(vaccinator, institution, assignment, finalReceipt, 2, ""));
    assertThat(completeRetry).isEqualTo(complete);
    assertThat(count("inventory_receipts")).isEqualTo(2);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isZero();
  }

  @Test
  void concurrentComplementaryReceiptsCannotClaimTheSameDifference() throws Exception {
    UUID assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Conteo"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment,
        lot, vaccinator, 10, now, "Entrega"));
    tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, assignment, UUID.randomUUID(), 8, "Faltante"));
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        start.await();
        try {
          tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, assignment, UUID.randomUUID(), 2, ""));
          return true;
        } catch (IllegalArgumentException ex) { return false; }
      })).toList();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
    assertThat(service.listAssignments(actor, institution).getFirst().receivedVials()).isEqualTo(10);
    assertThat(count("inventory_receipts")).isEqualTo(2);
  }

  @Test
  void depotRegularizationRequiresCorrectionCountConfirmationAndIsIdempotent() {
    UUID assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Conteo"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 10, now, "Entrega"));
    tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, assignment, UUID.randomUUID(), 8, "Faltante"));
    UUID correction = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.resolveDifference(actor, institution, assignment, correction, "DISPATCH_CORRECTION", 2, "Acta"));
    UUID id = UUID.randomUUID();
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.regularizeDepot(actor, institution, correction, id, 2, "Conteo", false)))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.regularizeDepot(actor, UUID.randomUUID(), correction, id, 2, "Conteo", true)))
        .isInstanceOf(ScopeViolationException.class);
    var result = tx.execute(s -> service.regularizeDepot(actor, institution, correction, id, 2, "Conteo físico", true));
    InventoryService.DepotRegularization replay = tx.execute(s -> service.regularizeDepot(actor, institution, correction, id, 2, "Conteo físico", true));
    assertThat(replay).isEqualTo(result);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.regularizeDepot(actor, institution, correction, id, 1, "Conteo físico", true)))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.regularizeDepot(actor, institution, correction, UUID.randomUUID(), 1, "Conteo", true)))
        .isInstanceOf(IllegalArgumentException.class);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(2);
    assertThat(service.listDifferenceResolutions(actor, institution, assignment).getFirst().regularizedVials()).isEqualTo(2);
    assertThat(service.listDepotRegularizations(actor, institution, correction)).singleElement()
        .satisfies(entry -> assertThat(entry.note()).isEqualTo("Conteo físico"));
    assertThat(db.queryForObject("SELECT kind FROM app.inventory_movements WHERE id = ?", String.class, id)).isEqualTo("DEPOT_CORRECTION");
  }

  @Test
  void expiredOrLostVialsCannotBeRegularizedAsAvailable() {
    UUID assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Conteo"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 10, now, "Entrega"));
    tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, assignment, UUID.randomUUID(), 8, "Faltante"));
    UUID lost = UUID.randomUUID();
    UUID correction = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.resolveDifference(actor, institution, assignment, lost, "LOST", 1, "Acta"));
    tx.executeWithoutResult(s -> service.resolveDifference(actor, institution, assignment, correction, "DISPATCH_CORRECTION", 1, "Acta"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.regularizeDepot(actor, institution, lost, UUID.randomUUID(), 1, "Conteo", true)))
        .isInstanceOf(IllegalArgumentException.class);
    db.update("UPDATE app.inventory_lots SET expires_on = ? WHERE id = ?", LocalDate.of(2025, 12, 31), lot);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.regularizeDepot(actor, institution, correction, UUID.randomUUID(), 1, "Conteo", true)))
        .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("vencido");
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isZero();
  }

  @Test
  void concurrentRegularizationsCannotCreditTheSameCorrectionTwice() throws Exception {
    UUID assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Conteo"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 10, now, "Entrega"));
    tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, assignment, UUID.randomUUID(), 8, "Faltante"));
    UUID correction = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.resolveDifference(actor, institution, assignment, correction, "DISPATCH_CORRECTION", 2, "Acta"));
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        start.await();
        try { tx.executeWithoutResult(s -> service.regularizeDepot(actor, institution, correction, UUID.randomUUID(), 2, "Conteo", true)); return true; }
        catch (IllegalArgumentException ex) { return false; }
      })).toList();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(2);
  }

  @Test
  void resolutionIsAuditableIdempotentAndNeverReturnsStockAutomatically() {
    UUID assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Conteo"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 10, now, "Entrega"));
    tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, assignment, UUID.randomUUID(), 6, "Faltan cuatro"));
    UUID correction = UUID.randomUUID();
    var resolved = tx.execute(s -> service.resolveDifference(actor, institution, assignment, correction,
        "DISPATCH_CORRECTION", 2, "Documento de despacho revisado"));
    InventoryService.DifferenceResolution retry = tx.execute(s -> service.resolveDifference(actor, institution, assignment,
        correction, "DISPATCH_CORRECTION", 2, "Documento de despacho revisado"));
    assertThat(retry).isEqualTo(resolved);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.resolveDifference(actor, institution, assignment,
        correction, "LOST", 2, "Documento de despacho revisado"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.resolveDifference(actor, UUID.randomUUID(), assignment,
        UUID.randomUUID(), "LOST", 1, "Evidencia"))).isInstanceOf(ScopeViolationException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.resolveDifference(actor, institution, assignment,
        UUID.randomUUID(), "LOST", 3, "Evidencia"))).isInstanceOf(IllegalArgumentException.class);
    var receipt = tx.execute(s -> service.receivePartial(vaccinator, institution, assignment, UUID.randomUUID(), 1, ""));
    assertThat(receipt.pendingDifference()).isEqualTo(1);
    tx.executeWithoutResult(s -> service.resolveDifference(actor, institution, assignment, UUID.randomUUID(),
        "LOST", 1, "Pérdida confirmada mediante acta"));
    var view = service.listAssignments(actor, institution).getFirst();
    assertThat(view.status()).isEqualTo("CLOSED_WITH_DIFFERENCE");
    assertThat(view.receivedVials()).isEqualTo(7);
    assertThat(view.resolvedVials()).isEqualTo(3);
    assertThat(service.listDifferenceResolutions(actor, institution, assignment)).hasSize(2);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isZero();
    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, UUID.randomUUID(), assignment, 7, "RETURN", "Conteo"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> custody.report(vaccinator, institution,
        UUID.randomUUID(), assignment, 1, "RETURN", "Exceso"))).isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  void concurrentResolutionAndReceiptCannotBothResolveTheSameVials() throws Exception {
    UUID assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Conteo"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment, lot, vaccinator, 10, now, "Entrega"));
    tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, assignment, UUID.randomUUID(), 8, "Faltante"));
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var reception = executor.submit(() -> {
        start.await();
        try { tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, assignment, UUID.randomUUID(), 2, "")); return true; }
        catch (IllegalArgumentException e) { return false; }
      });
      var resolution = executor.submit(() -> {
        start.await();
        try { tx.executeWithoutResult(s -> service.resolveDifference(actor, institution, assignment, UUID.randomUUID(), "LOST", 2, "Acta")); return true; }
        catch (IllegalArgumentException e) { return false; }
      });
      start.countDown();
      assertThat(List.of(reception.get(15, TimeUnit.SECONDS), resolution.get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
  }

  @Test
  void lotCreationRetriesRequireMatchingOperationActorAndData() {
    tx.executeWithoutResult(s -> service.createLot(actor, institution, lot, vaccine,
        "Fabricante", "Lote-1", LocalDate.of(2028, 1, 1), 10));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.createLot(actor, institution, lot, vaccine,
        "Fabricante", "Lote-1", LocalDate.of(2028, 1, 1), 11))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.createLot(vaccinator, institution, lot, vaccine,
        "Fabricante", "Lote-1", LocalDate.of(2028, 1, 1), 10))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.createLot(actor, UUID.randomUUID(), lot, vaccine,
        "Fabricante", "Lote-1", LocalDate.of(2028, 1, 1), 10))).isInstanceOf(ScopeViolationException.class);
    when(guard.require(actor, "INVENTORY_WRITE"))
        .thenThrow(new org.springframework.security.access.AccessDeniedException("denegado"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.createLot(actor, institution, lot, vaccine,
        "Fabricante", "Lote-1", LocalDate.of(2028, 1, 1), 10)))
        .isInstanceOf(org.springframework.security.access.AccessDeniedException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.createLotWithEntry(actor, institution, lot, vaccine,
        "Fabricante", "Lote-1", LocalDate.of(2028, 1, 1), 10, UUID.randomUUID(), 1, now, "Entrada")))
        .isInstanceOf(org.springframework.security.access.AccessDeniedException.class);
    assertThat(count("inventory_lots")).isEqualTo(1);
  }

  @Test
  void combinedLotEntryRetryDoesNotInferHistoricalOrSeparateOperations() {
    UUID id = UUID.randomUUID(), movement = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.createLotWithEntry(actor, institution, id, vaccine,
        "Fabricante", "Combinado", LocalDate.of(2028, 1, 1), 10, movement, 5, now, "Entrada"));
    tx.executeWithoutResult(s -> service.createLotWithEntry(actor, institution, id, vaccine,
        "Fabricante", "Combinado", LocalDate.of(2028, 1, 1), 10, movement, 5, now, "Entrada"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.createLotWithEntry(actor, institution, id, vaccine,
        "Fabricante", "Combinado", LocalDate.of(2028, 1, 1), 10, movement, 6, now, "Entrada")))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.createLotWithEntry(actor, institution, id, vaccine,
        "Fabricante", "Combinado", LocalDate.of(2028, 1, 1), 10, UUID.randomUUID(), 5, now, "Entrada")))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.createLotWithEntry(actor, institution, lot, vaccine,
        "Fabricante", "Lote-1", LocalDate.of(2028, 1, 1), 10, UUID.randomUUID(), 5, now, "Entrada")))
        .isInstanceOf(IllegalArgumentException.class);
    db.update("DELETE FROM app.inventory_lot_creation_operations WHERE lot_id = ?", lot);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.createLot(actor, institution, lot, vaccine,
        "Fabricante", "Lote-1", LocalDate.of(2028, 1, 1), 10))).isInstanceOf(IllegalArgumentException.class);
    assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, id)).isEqualTo(5);
    assertThat(count("inventory_movements")).isEqualTo(1);
  }

  @Test
  void concurrentIdenticalCombinedLotCreationsCommitOnce() throws Exception {
    UUID id = UUID.randomUUID(), movement = UUID.randomUUID();
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        start.await();
        return tx.execute(s -> service.createLotWithEntry(actor, institution, id, vaccine,
            "Fabricante", "Concurrencia", LocalDate.of(2028, 1, 1), 10, movement, 5, now, "Entrada"));
      })).toList();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactly(id, id);
    }
    assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, id)).isEqualTo(5);
    assertThat(count("inventory_movements")).isEqualTo(1);
    assertThat(count("inventory_lot_creation_operations")).isEqualTo(2);
  }

  @Test
  void concurrentIdenticalStandaloneLotRequestsReturnSameLot() throws Exception {
    UUID id = UUID.randomUUID();
    var ready = new CountDownLatch(2);
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        ready.countDown();
        if (!start.await(15, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        return tx.execute(s -> service.createLot(actor, institution, id, vaccine, "Fabricante",
            "Mismo lote", LocalDate.of(2028, 1, 1), 10));
      })).toList();
      assertThat(ready.await(15, TimeUnit.SECONDS)).isTrue();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactly(id, id);
    }
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_lot_creation_operations WHERE lot_id=?",
        Integer.class, id)).isEqualTo(1);
    assertThat(count("inventory_movements")).isZero();
  }

  @Test
  void concurrentConflictingCombinedRequestsCannotAddTwoEntries() throws Exception {
    UUID id = UUID.randomUUID(), movement = UUID.randomUUID();
    var ready = new CountDownLatch(2);
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        ready.countDown();
        if (!start.await(15, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        try {
          tx.executeWithoutResult(s -> service.createLotWithEntry(actor, institution, id, vaccine,
              "Fabricante", "Conflicto", LocalDate.of(2028, 1, 1), 10, movement, i + 1, now, "Entrada"));
          return true;
        } catch (IllegalArgumentException ex) { return false; }
      })).toList();
      assertThat(ready.await(15, TimeUnit.SECONDS)).isTrue();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
    int vials = db.queryForObject("SELECT vial_count FROM app.inventory_movements WHERE id=?", Integer.class, movement);
    assertThat(vials).isBetween(1, 2);
    assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, id))
        .isEqualTo(vials);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_lot_creation_operations WHERE lot_id=?",
        Integer.class, id)).isEqualTo(1);
    assertThat(count("inventory_movements")).isEqualTo(1);
  }

  @Test
  void concurrentContradictoryLotCreationsHaveOnlyOneWinner() throws Exception {
    UUID id = UUID.randomUUID();
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        start.await();
        try {
          tx.executeWithoutResult(s -> service.createLot(actor, institution, id, vaccine, "Fabricante",
              "Lote-" + i, LocalDate.of(2028, 1, 1), 10));
          return true;
        } catch (IllegalArgumentException e) { return false; }
      })).toList();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_lots WHERE id=?", Integer.class, id)).isEqualTo(1);
  }

  @Test
  void newLotAndEntryCommitTogetherAndRollbackOnDuplicateMovement() {
    UUID movement = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, movement, lot, 1, now, "Conteo"));
    UUID newLot = UUID.randomUUID();
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.createLotWithEntry(actor, institution,
        newLot, vaccine, "Fabricante", "Nuevo", LocalDate.of(2028, 1, 1), 10,
        movement, 5, now, "Entrada"))).isInstanceOf(IllegalArgumentException.class);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_lots WHERE id = ?", Integer.class, newLot)).isZero();
    UUID freshMovement = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.createLotWithEntry(actor, institution, newLot, vaccine,
        "Fabricante", "Nuevo", LocalDate.of(2028, 1, 1), 10, freshMovement, 5, now, "Entrada"));
    assertThat(service.listLots(actor, institution)).anySatisfy(item -> {
      assertThat(item.id()).isEqualTo(newLot);
      assertThat(item.availableVials()).isEqualTo(5);
    });
    assertThat(service.listMovements(actor, institution)).hasSize(2);
  }

  @Test
  void entryIsRecordedAndRetryDoesNotDuplicateBalance() {
    UUID movement = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, movement, lot, 10, now, "Conteo inicial"));
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, movement, lot, 10, now, "Conteo inicial"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.recordEntry(
        actor, institution, movement, lot, 9, now, "Conteo inicial")))
        .isInstanceOf(IllegalArgumentException.class);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(10);
    assertThat(count("inventory_movements")).isEqualTo(1);
  }

  @Test
  void dispatchRetryReturnsCurrentStatusAndRejectsConflictingData() {
    UUID entry = UUID.randomUUID(), movement = UUID.randomUUID(), assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, entry, lot, 5, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, movement, assignment, lot, vaccinator, 5, now, "Entrega"));
    tx.executeWithoutResult(s -> service.receive(vaccinator, institution, assignment, 5));
    db.update("UPDATE app.inventory_lots SET expires_on = ? WHERE id = ?", LocalDate.of(2025, 1, 1), lot);
    var replay = tx.execute(s -> service.dispatch(actor, institution, movement, assignment, lot, vaccinator, 5, now, "Entrega"));
    assertThat(replay.status()).isEqualTo(com.pai.api.inventory.domain.VialTransfer.Status.RECEIVED);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.dispatch(actor, institution, movement,
        assignment, lot, vaccinator, 4, now, "Entrega"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.dispatch(actor, institution, movement,
        UUID.randomUUID(), lot, vaccinator, 5, now, "Entrega"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.dispatch(actor, institution, movement,
        assignment, lot, UUID.randomUUID(), 5, now, "Entrega"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.dispatch(actor, institution, movement,
        assignment, lot, vaccinator, 5, now.plusSeconds(1), "Entrega"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.dispatch(actor, UUID.randomUUID(), movement,
        assignment, lot, vaccinator, 5, now, "Entrega"))).isInstanceOf(ScopeViolationException.class);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isZero();
    assertThat(count("inventory_movements")).isEqualTo(2);
    assertThat(count("inventory_assignments")).isEqualTo(1);
  }

  @Test
  void retriesStillRequireWritePermission() {
    UUID movement = UUID.randomUUID(), dispatch = UUID.randomUUID(), assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, movement, lot, 5, now, "Entrada"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, dispatch, assignment, lot, vaccinator, 5, now, "Entrega"));
    when(guard.require(actor, "INVENTORY_WRITE")).thenThrow(new org.springframework.security.access.AccessDeniedException("denegado"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.recordEntry(actor, institution, movement, lot, 5, now, "Entrada")))
        .isInstanceOf(org.springframework.security.access.AccessDeniedException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.dispatch(actor, institution, dispatch,
        assignment, lot, vaccinator, 5, now, "Entrega")))
        .isInstanceOf(org.springframework.security.access.AccessDeniedException.class);
  }

  @Test
  void concurrentIdenticalEntriesAndDispatchesAreAppliedOnce() throws Exception {
    UUID movement = UUID.randomUUID(), dispatch = UUID.randomUUID(), assignment = UUID.randomUUID();
    var startEntry = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var entries = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        startEntry.await();
        tx.executeWithoutResult(s -> service.recordEntry(actor, institution, movement, lot, 5, now, "Entrada"));
        return true;
      })).toList();
      startEntry.countDown();
      assertThat(List.of(entries.get(0).get(15, TimeUnit.SECONDS), entries.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactly(true, true);
      var startDispatch = new CountDownLatch(1);
      var deliveries = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        startDispatch.await();
        tx.executeWithoutResult(s -> service.dispatch(actor, institution, dispatch, assignment,
            lot, vaccinator, 5, now, "Entrega"));
        return true;
      })).toList();
      startDispatch.countDown();
      assertThat(List.of(deliveries.get(0).get(15, TimeUnit.SECONDS), deliveries.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactly(true, true);
    }
    assertThat(count("inventory_movements")).isEqualTo(2);
    assertThat(count("inventory_assignments")).isEqualTo(1);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isZero();
  }

  @Test
  void concurrentContradictoryEntryRetriesCannotBothSucceed() throws Exception {
    UUID movement = UUID.randomUUID();
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        start.await();
        try {
          tx.executeWithoutResult(s -> service.recordEntry(actor, institution, movement, lot, i + 1, now, "Entrada"));
          return true;
        } catch (IllegalArgumentException ex) { return false; }
      })).toList();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
    int recorded = db.queryForObject("SELECT vial_count FROM app.inventory_movements WHERE id=?", Integer.class, movement);
    assertThat(recorded).isBetween(1, 2);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(recorded);
    assertThat(count("inventory_movements")).isEqualTo(1);
  }

  @Test
  void scopeAndRecipientAreCheckedBeforeStockChanges() {
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.recordEntry(
        actor, UUID.randomUUID(), UUID.randomUUID(), lot, 5, now, "Entrada")))
        .isInstanceOf(ScopeViolationException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.dispatch(actor, institution,
        UUID.randomUUID(), UUID.randomUUID(), lot, UUID.randomUUID(), 1, now, "Entrega")))
        .isInstanceOf(IllegalArgumentException.class);
    assertThat(count("inventory_movements")).isZero();
  }

  @Test
  void duplicateMovementRollsBackNewAssignment() {
    UUID movement = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, movement, lot, 10, now, "Conteo"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.dispatch(actor, institution,
        movement, UUID.randomUUID(), lot, vaccinator, 4, now, "Entrega")))
        .isInstanceOf(IllegalArgumentException.class);
    assertThat(count("inventory_assignments")).isZero();
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(10);
    assertThat(count("inventory_movements")).isEqualTo(1);
  }

  @Test
  void receiptIsRestrictedToRecipientAndFullQuantityAndCanBeRetried() {
    UUID assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 5, now, "Conteo"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment,
        lot, vaccinator, 3, now, "Entrega"));
    assertThat(service.listMyAssignments(actor, institution)).isEmpty();
    assertThat(service.listMyAssignments(vaccinator, institution)).singleElement()
        .satisfies(item -> assertThat(item.lotNumber()).isEqualTo("Lote-1"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.receive(actor, institution, assignment, 3)))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.receive(vaccinator, institution, assignment, 2)))
        .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("incidencia");
    assertThat(tx.execute(s -> service.receive(vaccinator, institution, assignment, 3)).status())
        .isEqualTo(com.pai.api.inventory.domain.VialTransfer.Status.RECEIVED);
    assertThat(tx.execute(s -> service.receive(vaccinator, institution, assignment, 3)).status())
        .isEqualTo(com.pai.api.inventory.domain.VialTransfer.Status.RECEIVED);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(2);
    assertThat(count("inventory_movements")).isEqualTo(2);
  }

  @Test
  void aLotFromAnotherInstitutionCannotBeCredited() {
    UUID otherLot = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_lots (id, institution_id, vaccine_id, manufacturer, lot_number, "
            + "expires_on, doses_per_vial, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        otherLot, UUID.randomUUID(), vaccine, "Fabricante", "Lote-2", LocalDate.of(2028, 1, 1), 1, actor);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.recordEntry(actor, institution,
        UUID.randomUUID(), otherLot, 4, now, "Entrada")))
        .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("no encontrado");
    assertThat(count("inventory_movements")).isZero();
  }

  @Test
  void campaignGroupsOptionalAssignmentsAndFinishingLeavesCustodyUntouched() {
    UUID campaign = UUID.randomUUID();
    UUID assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> campaigns.create(actor, institution, campaign, "Jornada", "Centro", LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 2)));
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Conteo"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment,
        lot, vaccinator, 3, now, "Entrega", campaign));
    tx.executeWithoutResult(s -> campaigns.addParticipant(actor, institution, campaign, vaccinator));
    assertThat(campaigns.participants(actor, institution, campaign)).hasSize(1);
    tx.executeWithoutResult(s -> campaigns.finish(actor, institution, campaign));
    tx.executeWithoutResult(s -> campaigns.finish(actor, institution, campaign));
    assertThat(campaigns.list(actor, institution).getFirst().status()).isEqualTo("FINISHED");
    assertThat(service.listAssignments(actor, institution).getFirst().campaignId()).isEqualTo(campaign);
    assertThat(tx.execute(s -> service.receive(vaccinator, institution, assignment, 3)).campaignId()).isEqualTo(campaign);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(7);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(),
        UUID.randomUUID(), lot, vaccinator, 1, now, "Entrega", campaign)))
        .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("finalizo");
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(),
        UUID.randomUUID(), lot, vaccinator, 1, now, "Entrega sin jornada"));
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(6);
  }

  @Test
  void campaignRejectsOtherInstitutionAndInvalidDates() {
    UUID campaign = UUID.randomUUID();
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> campaigns.create(actor, institution, campaign, "J", "L",
        LocalDate.of(2026, 1, 2), LocalDate.of(2026, 1, 1)))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> campaigns.create(actor, UUID.randomUUID(), campaign, "J", "L",
        LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 1)))).isInstanceOf(ScopeViolationException.class);
    db.update("INSERT INTO app.inventory_campaigns (id, institution_id, name, location, starts_on, ends_on, status) "
        + "VALUES (?, ?, 'J', 'L', ?, ?, 'ACTIVE')", campaign, UUID.randomUUID(), LocalDate.now(), LocalDate.now());
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(),
        UUID.randomUUID(), lot, vaccinator, 1, now, "Entrega", campaign))).isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  void returnIsNotAvailableUntilConfirmedAndConfirmationIsIdempotent() {
    UUID assignment = receivedAssignment(8);
    UUID event = UUID.randomUUID();
    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, event, assignment, 3, "RETURN", "Frascos cerrados"));
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(2);
    assertThat(custody.list(vaccinator, institution, true).getFirst().status()).isEqualTo("RETURN_PENDING");
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> custody.confirmReturn(actor, institution,
        event, "AVAILABLE", " "))).isInstanceOf(IllegalArgumentException.class);
    tx.executeWithoutResult(s -> custody.confirmReturn(actor, institution, event, "AVAILABLE", "Recepcion y revision fisica"));
    tx.executeWithoutResult(s -> custody.confirmReturn(actor, institution, event, "AVAILABLE", "Recepcion y revision fisica"));
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(5);
    assertThat(count("inventory_movements")).isEqualTo(3);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> custody.confirmReturn(actor, institution,
        event, "QUARANTINE", "Cambio"))).isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  void quarantineAndIncidentsNeverIncreaseDepotStockOrDoubleDeclare() {
    UUID assignment = receivedAssignment(8);
    UUID returned = UUID.randomUUID();
    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, returned, assignment, 3, "RETURN", "Revision"));
    tx.executeWithoutResult(s -> custody.confirmReturn(actor, institution, returned, "QUARANTINE", "Cadena por verificar"));
    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, UUID.randomUUID(), assignment, 4, "LOST", "Novedad"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> custody.report(vaccinator, institution,
        UUID.randomUUID(), assignment, 2, "QUARANTINE", "Otro"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> custody.report(actor, institution,
        UUID.randomUUID(), assignment, 1, "RETURN", "Otro"))).isInstanceOf(IllegalArgumentException.class);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(2);
    assertThat(count("inventory_movements")).isEqualTo(2);
  }

  @Test
  void concurrentDeclarationsCannotExceedReceivedAssignment() throws Exception {
    UUID assignment = receivedAssignment(8);
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        start.await();
        try {
          tx.executeWithoutResult(s -> custody.report(vaccinator, institution, UUID.randomUUID(), assignment, 5, "RETURN", "Devolucion"));
          return true;
        } catch (IllegalArgumentException e) { return false; }
      })).toList();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
    assertThat(count("inventory_custody_events")).isEqualTo(1);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(2);
  }

  private UUID receivedAssignment(int vials) {
    UUID assignment = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Conteo"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment,
        lot, vaccinator, vials, now, "Entrega"));
    tx.executeWithoutResult(s -> service.receive(vaccinator, institution, assignment, vials));
    return assignment;
  }

  @Test
  void reserveIsExclusiveAndIdempotentAndDoesNotChangeDepotStock() {
    UUID assignment = receivedAssignment(8);
    UUID installation = UUID.randomUUID();
    UUID reservation = UUID.randomUUID();
    tx.executeWithoutResult(s -> reservations.register(vaccinator, institution, installation, "Equipo A"));
    tx.executeWithoutResult(s -> reservations.register(vaccinator, institution, installation, "Equipo A"));
    assertThat(tx.execute(s -> reservations.reserve(actor, institution, reservation, assignment, installation, 5)).vialCount()).isEqualTo(5);
    tx.executeWithoutResult(s -> reservations.reserve(actor, institution, reservation, assignment, installation, 5));
    assertThat(count("inventory_installation_reservations")).isEqualTo(1);
    // La reserva es visible sin introducir existencias nuevas en deposito.
    assertThat(reservations.listReservations(actor, institution)).hasSize(1);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> reservations.reserve(actor, institution,
        reservation, assignment, installation, 4))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> reservations.reserve(actor, institution,
        UUID.randomUUID(), assignment, installation, 4))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> custody.report(vaccinator, institution,
        UUID.randomUUID(), assignment, 4, "RETURN", "Sobrante"))).isInstanceOf(IllegalArgumentException.class);
    // Reportar una perdida nunca libera la cuota ni exige ocultar la incidencia.
    tx.executeWithoutResult(s -> custody.report(vaccinator, institution, UUID.randomUUID(), assignment, 5, "LOST", "Incidencia"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> reservations.reserve(actor, institution,
        UUID.randomUUID(), assignment, installation, 1))).isInstanceOf(IllegalArgumentException.class);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(2);
  }

  @Test
  void reservationRejectsOtherCustodianOrInstitution() {
    UUID assignment = receivedAssignment(8);
    UUID installation = UUID.randomUUID();
    UUID other = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_installations (id, institution_id, vaccinator_id, label) VALUES (?, ?, ?, ?)",
        installation, institution, other, "Otro");
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> reservations.reserve(actor, institution,
        UUID.randomUUID(), assignment, installation, 1))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> reservations.reserve(actor, UUID.randomUUID(),
        UUID.randomUUID(), assignment, installation, 1))).isInstanceOf(ScopeViolationException.class);
  }

  @Test
  void installationAndReservationListsRejectOtherInstitution() {
    UUID otherInstitution = UUID.randomUUID();
    assertThatThrownBy(() -> reservations.list(actor, otherInstitution))
        .isInstanceOf(ScopeViolationException.class);
    assertThatThrownBy(() -> reservations.listReservations(actor, otherInstitution))
        .isInstanceOf(ScopeViolationException.class);
  }

  @Test
  void concurrentReservationsCannotCommitTheSameVialsTwice() throws Exception {
    UUID assignment = receivedAssignment(8);
    UUID first = UUID.randomUUID();
    UUID second = UUID.randomUUID();
    tx.executeWithoutResult(s -> reservations.register(vaccinator, institution, first, "Equipo A"));
    tx.executeWithoutResult(s -> reservations.register(vaccinator, institution, second, "Equipo B"));
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.Stream.of(first, second).map(device -> executor.submit(() -> {
        start.await();
        try {
          tx.executeWithoutResult(s -> reservations.reserve(actor, institution, UUID.randomUUID(), assignment, device, 5));
          return true;
        } catch (IllegalArgumentException e) { return false; }
      })).toList();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
    assertThat(count("inventory_installation_reservations")).isEqualTo(1);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(2);
  }

  @Test
  void concurrentReturnAndReservationCannotClaimSameVials() throws Exception {
    UUID assignment = receivedAssignment(8);
    UUID installation = UUID.randomUUID();
    tx.executeWithoutResult(s -> reservations.register(vaccinator, institution, installation, "Equipo"));
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var reserve = executor.submit(() -> {
        start.await();
        try {
          tx.executeWithoutResult(s -> reservations.reserve(actor, institution, UUID.randomUUID(), assignment, installation, 5));
          return true;
        } catch (IllegalArgumentException e) { return false; }
      });
      var report = executor.submit(() -> {
        start.await();
        try {
          tx.executeWithoutResult(s -> custody.report(vaccinator, institution, UUID.randomUUID(), assignment, 5, "RETURN", "Sobrante"));
          return true;
        } catch (IllegalArgumentException e) { return false; }
      });
      start.countDown();
      assertThat(List.of(reserve.get(15, TimeUnit.SECONDS), report.get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(2);
  }

  @Test
  void concurrentDispatchesCannotBothSpendSameStock() throws Exception {
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, now, "Conteo"));
    var ready = new CountDownLatch(2);
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        ready.countDown();
        if (!start.await(10, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        try {
          tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(),
              UUID.randomUUID(), lot, vaccinator, 7, now, "Entrega"));
          return true;
        } catch (IllegalArgumentException ex) {
          return false;
        }
      })).toList();
      assertThat(ready.await(10, TimeUnit.SECONDS)).isTrue();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(15, TimeUnit.SECONDS), tasks.get(1).get(15, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(3);
    assertThat(count("inventory_assignments")).isEqualTo(1);
    assertThat(count("inventory_movements")).isEqualTo(2);
  }

  private int count(String table) {
    return db.queryForObject("SELECT count(*) FROM app." + table, Integer.class);
  }
}
