package com.pai.api.inventory.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.security.PermissionGuard;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.init.ScriptUtils;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;

/**
 * Prueba opt-in en base vacia y dedicada. No limpia ni elimina bases o esquemas.
 * El esquema anterior a V33 es minimo: no certifica las migraciones V1-V32 completas.
 */
@EnabledIfEnvironmentVariable(named = "PAI_DISPOSABLE_PG_RUN", matches = "true")
class DisposablePostgresInventoryTest {
  @Test
  void migrationsAndConcurrentRegularizationOnDisposableDatabase() throws Exception {
    String url = System.getenv("PAI_DISPOSABLE_PG_URL");
    String user = System.getenv("PAI_DISPOSABLE_PG_USER");
    String password = System.getenv("PAI_DISPOSABLE_PG_PASSWORD");
    String expectedDatabase = DisposablePostgresConfig.validate(url, user, password);
    var source = new DriverManagerDataSource(url, user, password);
    var db = new JdbcTemplate(source);
    assertThat(db.queryForObject("SELECT current_database()", String.class)).isEqualTo(expectedDatabase);
    assertThat(db.queryForObject("SELECT current_user", String.class)).isEqualTo(user);
    assertThat(db.queryForObject("SELECT host(inet_server_addr())", String.class))
        .isEqualTo("127.0.0.1");
    assertThat(db.queryForObject("SELECT count(*) FROM pg_namespace WHERE nspname='app'", Integer.class))
        .as("La base debe ser nueva: no se sobrescribe un esquema app existente").isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
        + "WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m','f','S')", Integer.class))
        .as("La base debe estar vacía").isZero();

    db.execute("CREATE SCHEMA app");
    db.execute("CREATE TABLE app.institutions (id UUID PRIMARY KEY)");
    db.execute("CREATE TABLE app.vaccines (id UUID PRIMARY KEY, name TEXT NOT NULL)");
    db.execute("CREATE TABLE app.users (id UUID PRIMARY KEY, institution_id UUID, status TEXT, full_name TEXT)");
    db.execute("CREATE TABLE app.roles (id UUID PRIMARY KEY, code TEXT)");
    db.execute("CREATE TABLE app.user_roles (user_id UUID, role_id UUID)");
    try (var connection = source.getConnection()) {
      for (String migration : List.of("V20__inventory_foundation.sql", "V21__inventory_campaigns.sql",
          "V22__custody_returns_and_incidents.sql")) {
        ScriptUtils.executeSqlScript(connection, new ClassPathResource("db/migration/" + migration));
      }
    }
    UUID institution = UUID.randomUUID(), actor = UUID.randomUUID(), vaccinator = UUID.randomUUID();
    UUID vaccine = UUID.randomUUID(), lot = UUID.randomUUID(), role = UUID.randomUUID();
    UUID historicalLot = UUID.randomUUID(), historicalReceived = UUID.randomUUID();
    UUID historicalTransit = UUID.randomUUID(), historicalMovement = UUID.randomUUID();
    db.update("INSERT INTO app.institutions VALUES (?)", institution);
    db.update("INSERT INTO app.vaccines VALUES (?, ?)", vaccine, "Vacuna prueba aislada");
    db.update("INSERT INTO app.users VALUES (?, ?, 'ACTIVE', 'Administrador')", actor, institution);
    db.update("INSERT INTO app.users VALUES (?, ?, 'ACTIVE', 'Vacunador')", vaccinator, institution);
    db.update("INSERT INTO app.roles VALUES (?, 'VACCINATOR')", role);
    db.update("INSERT INTO app.user_roles VALUES (?, ?)", vaccinator, role);
    db.update("INSERT INTO app.inventory_lots (id, institution_id, vaccine_id, manufacturer, lot_number, "
            + "expires_on, doses_per_vial, available_vials, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        historicalLot, institution, vaccine, "Prueba aislada", "HISTORICO",
        LocalDate.of(2099, 1, 1), 10, 4, actor);
    db.update("INSERT INTO app.inventory_assignments (id, institution_id, lot_id, vaccinator_id, vial_count, "
            + "status, dispatched_by, received_at) VALUES (?, ?, ?, ?, ?, 'RECEIVED', ?, CURRENT_TIMESTAMP)",
        historicalReceived, institution, historicalLot, vaccinator, 6, actor);
    db.update("INSERT INTO app.inventory_assignments (id, institution_id, lot_id, vaccinator_id, vial_count, "
            + "status, dispatched_by) VALUES (?, ?, ?, ?, ?, 'IN_TRANSIT', ?)",
        historicalTransit, institution, historicalLot, vaccinator, 3, actor);
    db.update("INSERT INTO app.inventory_movements (id, institution_id, lot_id, assignment_id, kind, "
            + "vial_count, occurred_at, recorded_by, note) VALUES (?, ?, ?, ?, 'DISPATCH', 6, CURRENT_TIMESTAMP, ?, ?)",
        historicalMovement, institution, historicalLot, historicalReceived, actor, "Despacho histórico de prueba");
    Flyway flyway = Flyway.configure().dataSource(source).schemas("app")
        .locations("classpath:db/migration").baselineOnMigrate(true).baselineVersion("32")
        .validateOnMigrate(true).load();
    assertThat(flyway.migrate().migrationsExecuted).isEqualTo(5);
    assertThat(flyway.migrate().migrationsExecuted).isZero();
    assertThat(db.queryForMap("SELECT vial_count, received_vials, resolved_vials, status FROM "
        + "app.inventory_assignments WHERE id = ?", historicalReceived))
        .containsEntry("vial_count", 6).containsEntry("received_vials", 6)
        .containsEntry("resolved_vials", 0).containsEntry("status", "RECEIVED");
    assertThat(db.queryForMap("SELECT vial_count, received_vials, resolved_vials, status FROM "
        + "app.inventory_assignments WHERE id = ?", historicalTransit))
        .containsEntry("vial_count", 3).containsEntry("received_vials", 0)
        .containsEntry("resolved_vials", 0).containsEntry("status", "IN_TRANSIT");
    assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, historicalLot))
        .isEqualTo(4);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements WHERE id=?", Integer.class, historicalMovement))
        .isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts", Integer.class)).isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM pg_constraint WHERE conrelid = "
        + "'app.inventory_receipts'::regclass AND conname = 'ck_receipt_difference_note'", Integer.class)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_difference_resolutions", Integer.class)).isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_depot_regularizations", Integer.class)).isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_lot_creation_operations", Integer.class)).isZero();
    var guard = mock(PermissionGuard.class);
    var profile = mock(AuthorizedUser.class);
    var institutionProfile = mock(InstitutionEntity.class);
    when(institutionProfile.getId()).thenReturn(institution);
    when(profile.getInstitution()).thenReturn(institutionProfile);
    when(profile.getPermissions()).thenReturn(List.of("INVENTORY_READ", "INVENTORY_WRITE"));
    when(profile.getRoles()).thenReturn(List.of("VACCINATOR"));
    when(guard.require(any(), any())).thenReturn(profile);
    var service = new InventoryService(db, guard, new DataScope());
    var tx = new TransactionTemplate(new DataSourceTransactionManager(source));
    var pausingDb = new HistoricalReviewIntegrationTest.PausingJdbcTemplate(source);
    var transactionManager = new DataSourceTransactionManager(source);
    var proxy = new ProxyFactory(new InventoryService(pausingDb, guard, new DataScope()));
    proxy.setProxyTargetClass(true);
    proxy.addAdvice(new TransactionInterceptor(transactionManager, new AnnotationTransactionAttributeSource()));
    var transactionalReview = (InventoryService) proxy.getProxy();
    UUID concurrentReceipt = UUID.randomUUID();
    pausingDb.pauseAfterAssignment = true;
    try (var executor = Executors.newSingleThreadExecutor()) {
      var reviewFuture = executor.submit(() -> transactionalReview.reviewHistoricalCustody(actor, institution, historicalTransit));
      try {
        assertThat(pausingDb.assignmentRead.await(20, TimeUnit.SECONDS)).isTrue();
        tx.executeWithoutResult(s -> {
          db.update("UPDATE app.inventory_assignments SET received_vials=3, status='RECEIVED', "
              + "received_at=CURRENT_TIMESTAMP WHERE institution_id=? AND id=?", institution, historicalTransit);
          db.update("INSERT INTO app.inventory_receipts (id, institution_id, assignment_id, lot_id, received_by, vials, difference_note) "
              + "VALUES (?, ?, ?, ?, ?, 3, '')", concurrentReceipt, institution, historicalTransit, historicalLot, vaccinator);
        });
      } finally {
        pausingDb.continueReview.countDown();
      }
      var snapshot = reviewFuture.get(20, TimeUnit.SECONDS);
      assertThat(snapshot.receivedVials()).isZero();
      assertThat(snapshot.status()).isEqualTo("IN_TRANSIT");
      assertThat(snapshot.receipts()).isEmpty();
      assertThat(snapshot.reviewReasons()).isEmpty();
    }
    pausingDb.pauseAfterAssignment = false;
    var latestReview = transactionalReview.reviewHistoricalCustody(actor, institution, historicalTransit);
    assertThat(latestReview.receivedVials()).isEqualTo(3);
    assertThat(latestReview.receipts()).extracting(InventoryService.HistoricalReceipt::id).containsExactly(concurrentReceipt);
    assertThat(latestReview.reviewReasons()).isEmpty();
    assertThat(org.assertj.core.api.Assertions.catchThrowable(
        () -> transactionalReview.reviewHistoricalCustody(actor, UUID.randomUUID(), historicalTransit)))
        .isInstanceOf(com.pai.api.shared.exceptions.ScopeViolationException.class);
    for (boolean combined : List.of(false, true)) {
      for (boolean conflicting : List.of(false, true)) {
        UUID concurrentLot = UUID.randomUUID(), concurrentMovement = UUID.randomUUID();
        String number = "C-" + concurrentLot;
        var ready = new CountDownLatch(2);
        var startCreation = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
          var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
            ready.countDown();
            if (!startCreation.await(20, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
            try {
              tx.executeWithoutResult(s -> {
                if (combined) {
                  service.createLotWithEntry(actor, institution, concurrentLot, vaccine, "Prueba aislada",
                      number, LocalDate.of(2099, 1, 1), 10, concurrentMovement,
                      conflicting ? i + 1 : 2, Instant.parse("2026-01-01T00:00:00Z"), "Entrada");
                } else {
                  service.createLot(actor, institution, concurrentLot, vaccine, "Prueba aislada",
                      number, LocalDate.of(2099, 1, 1), conflicting ? 10 + i : 10);
                }
              });
              return true;
            } catch (IllegalArgumentException ex) { return false; }
          })).toList();
          assertThat(ready.await(20, TimeUnit.SECONDS)).isTrue();
          startCreation.countDown();
          var results = List.of(tasks.get(0).get(20, TimeUnit.SECONDS), tasks.get(1).get(20, TimeUnit.SECONDS));
          if (conflicting) assertThat(results).containsExactlyInAnyOrder(true, false);
          else assertThat(results).containsExactly(true, true);
        }
        assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_lots WHERE id=?", Integer.class, concurrentLot))
            .isEqualTo(1);
        assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_lot_creation_operations WHERE lot_id=?",
            Integer.class, concurrentLot)).isEqualTo(1);
        assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements WHERE id=?", Integer.class, concurrentMovement))
            .isEqualTo(combined ? 1 : 0);
        int expectedBalance = combined ? db.queryForObject(
            "SELECT vial_count FROM app.inventory_movements WHERE id=?", Integer.class, concurrentMovement) : 0;
        assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, concurrentLot))
            .isEqualTo(expectedBalance);
      }
    }
    UUID combinedLot = UUID.randomUUID(), combinedMovement = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.createLotWithEntry(actor, institution, combinedLot, vaccine,
        "Prueba aislada", "COMBINADO", LocalDate.of(2099, 1, 1), 10,
        combinedMovement, 4, Instant.parse("2026-01-01T00:00:00Z"), "Entrada"));
    tx.executeWithoutResult(s -> service.createLotWithEntry(actor, institution, combinedLot, vaccine,
        "Prueba aislada", "COMBINADO", LocalDate.of(2099, 1, 1), 10,
        combinedMovement, 4, Instant.parse("2026-01-01T00:00:00Z"), "Entrada"));
    assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, combinedLot))
        .isEqualTo(4);
    UUID assignment = UUID.randomUUID(), receipt = UUID.randomUUID(), correction = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.createLot(actor, institution, lot, vaccine,
        "Prueba aislada", "PRUEBA", LocalDate.of(2099, 1, 1), 10));
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 10, Instant.now(), "Prueba"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), assignment,
        lot, vaccinator, 10, Instant.now(), "Prueba"));
    var partial = tx.execute(s -> service.receivePartial(vaccinator, institution, assignment, receipt, 8, "Faltante"));
    assertThat(partial.pendingDifference()).isEqualTo(2);
    var review = service.reviewHistoricalCustody(actor, institution, assignment);
    assertThat(review.receipts()).extracting(InventoryService.HistoricalReceipt::id).containsExactly(receipt);
    assertThat(review.reviewReasons()).isEmpty();
    InventoryService.ReceiptResult replay =
        tx.execute(s -> service.receivePartial(vaccinator, institution, assignment, receipt, 8, "Faltante"));
    assertThat(replay).isEqualTo(partial);
    tx.executeWithoutResult(s -> service.resolveDifference(actor, institution, assignment, correction,
        "DISPATCH_CORRECTION", 2, "Acta de prueba"));
    assertThat(service.listPendingFollowUps(actor, institution)).anySatisfy(item -> {
      assertThat(item.id()).isEqualTo(correction);
      assertThat(item.kind()).isEqualTo("DISPATCH_CORRECTION");
      assertThat(item.pendingVials()).isEqualTo(2);
    });
    var start = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        start.await();
        try {
          tx.executeWithoutResult(s -> service.regularizeDepot(actor, institution, correction,
              UUID.randomUUID(), 2, "Conteo de prueba", true));
          return true;
        } catch (IllegalArgumentException ex) {
          return false;
        }
      })).toList();
      start.countDown();
      assertThat(List.of(tasks.get(0).get(20, TimeUnit.SECONDS), tasks.get(1).get(20, TimeUnit.SECONDS)))
          .containsExactlyInAnyOrder(true, false);
    }
    assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, lot))
        .isEqualTo(2);
    assertThat(service.listDepotRegularizations(actor, institution, correction)).hasSize(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements WHERE kind='DEPOT_CORRECTION'",
        Integer.class)).isEqualTo(1);

    UUID contested = UUID.randomUUID(), contestedReceipt = UUID.randomUUID(), contestedResolution = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 8, Instant.now(), "Prueba"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), contested,
        lot, vaccinator, 10, Instant.now(), "Prueba"));
    tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, contested, UUID.randomUUID(), 8, "Faltante"));
    var ready = new CountDownLatch(2);
    var compete = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var reception = executor.submit(() -> {
        ready.countDown();
        if (!compete.await(20, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        try {
          tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, contested, contestedReceipt, 2, ""));
          return true;
        } catch (IllegalArgumentException ex) { return false; }
      });
      var resolution = executor.submit(() -> {
        ready.countDown();
        if (!compete.await(20, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        try {
          tx.executeWithoutResult(s -> service.resolveDifference(actor, institution, contested, contestedResolution,
              "LOST", 2, "Acta de prueba"));
          return true;
        } catch (IllegalArgumentException ex) { return false; }
      });
      assertThat(ready.await(20, TimeUnit.SECONDS)).isTrue();
      compete.countDown();
      boolean received = reception.get(20, TimeUnit.SECONDS);
      boolean resolved = resolution.get(20, TimeUnit.SECONDS);
      assertThat(List.of(received, resolved)).containsExactlyInAnyOrder(true, false);
      var result = db.queryForMap("SELECT received_vials, resolved_vials, status FROM app.inventory_assignments WHERE id=?",
          contested);
      assertThat(result).containsEntry("received_vials", received ? 10 : 8)
          .containsEntry("resolved_vials", resolved ? 2 : 0)
          .containsEntry("status", received ? "RECEIVED" : "CLOSED_WITH_DIFFERENCE");
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts WHERE id=?", Integer.class, contestedReceipt))
          .isEqualTo(received ? 1 : 0);
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_difference_resolutions WHERE id=?",
          Integer.class, contestedResolution)).isEqualTo(resolved ? 1 : 0);
    }
    assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, lot))
        .isZero();

    // Esquema y servicio candidatos solo sobre esta base desechable; no son migraciones.
    try (var connection = source.getConnection()) {
      ScriptUtils.executeSqlScript(connection, new ClassPathResource("inventory/individual_custody_candidate.sql"));
    }
    var candidate = new CandidateCustodyLinkService(db, guard, new DataScope());
    UUID candidateCustody = UUID.randomUUID();
    long movementsBefore = db.queryForObject("SELECT count(*) FROM app.inventory_movements", Long.class);
    int depotBefore = db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, lot);
    when(guard.require(actor, "INVENTORY_WRITE"))
        .thenThrow(new org.springframework.security.access.AccessDeniedException("denegado"));
    assertThatThrownBy(() -> tx.execute(s -> candidate.link(actor, institution, candidateCustody, assignment)))
        .isInstanceOf(org.springframework.security.access.AccessDeniedException.class);
    org.mockito.Mockito.doReturn(profile).when(guard).require(actor, "INVENTORY_WRITE");
    assertThatThrownBy(() -> tx.execute(s -> candidate.link(actor, UUID.randomUUID(), candidateCustody, assignment)))
        .isInstanceOf(com.pai.api.shared.exceptions.ScopeViolationException.class);
    UUID inTransit = UUID.randomUUID(), invalidReceipt = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_assignments (id,institution_id,lot_id,vaccinator_id,vial_count,status,dispatched_by) "
        + "VALUES (?,?,?,?,3,'IN_TRANSIT',?)", inTransit, institution, lot, vaccinator, actor);
    assertThatThrownBy(() -> tx.execute(s -> candidate.link(actor, institution, candidateCustody, inTransit)))
        .isInstanceOf(IllegalArgumentException.class);
    db.update("INSERT INTO app.inventory_assignments (id,institution_id,lot_id,vaccinator_id,vial_count,received_vials,status,dispatched_by) "
        + "VALUES (?,?,?,?,3,2,'PARTIALLY_RECEIVED',?)", invalidReceipt, institution, lot, vaccinator, actor);
    db.update("INSERT INTO app.inventory_receipts (id,institution_id,assignment_id,lot_id,received_by,vials,difference_note) "
        + "VALUES (?,?,?,?,?,1,'Faltante')", UUID.randomUUID(), institution, invalidReceipt, lot, vaccinator);
    assertThatThrownBy(() -> tx.execute(s -> candidate.link(actor, institution, candidateCustody, invalidReceipt)))
        .isInstanceOf(IllegalArgumentException.class);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custodies_candidate", Integer.class)).isZero();

    var candidateReady = new CountDownLatch(2);
    var candidateStart = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var links = List.of(assignment, contested).stream().map(id -> executor.submit(() -> {
        candidateReady.countDown();
        if (!candidateStart.await(20, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        return tx.execute(s -> candidate.link(actor, institution, candidateCustody, id));
      })).toList();
      assertThat(candidateReady.await(20, TimeUnit.SECONDS)).isTrue();
      candidateStart.countDown();
      assertThat(List.of(links.get(0).get(20, TimeUnit.SECONDS), links.get(1).get(20, TimeUnit.SECONDS)))
          .containsExactly(candidateCustody, candidateCustody);
    }
    UUID candidateRetry = tx.execute(s -> candidate.link(actor, institution, candidateCustody, assignment));
    assertThat(candidateRetry).isEqualTo(candidateCustody);
    assertThatThrownBy(() -> tx.execute(s -> candidate.link(actor, institution, UUID.randomUUID(), assignment)))
        .isInstanceOf(IllegalArgumentException.class);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custodies_candidate", Integer.class)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate WHERE custody_id=?",
        Integer.class, candidateCustody)).isEqualTo(2);
    try (var connection = source.getConnection()) {
      ScriptUtils.executeSqlScript(connection, new ClassPathResource("inventory/transfer_finalization_candidate.sql"));
    }
    var custodyReview = new CandidateCustodyReviewService(db, guard, new DataScope())
        .review(actor, institution, candidateCustody);
    assertThat(custodyReview.origins()).extracting(CandidateCustodyReviewService.Origin::assignmentId)
        .containsExactlyInAnyOrder(assignment, contested);
    UUID recordedRegularization = db.queryForObject(
        "SELECT id FROM app.inventory_depot_regularizations WHERE institution_id=? AND resolution_id=?",
        UUID.class, institution, correction);
    assertThat(custodyReview.origins()).anySatisfy(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(assignment);
      assertThat(origin.receipts()).extracting(CandidateCustodyReviewService.Receipt::id).contains(receipt);
      assertThat(origin.resolutions()).singleElement().satisfies(resolution -> {
        assertThat(resolution.id()).isEqualTo(correction);
        assertThat(resolution.kind()).isEqualTo("DISPATCH_CORRECTION");
        assertThat(resolution.regularizations()).singleElement().satisfies(regularization -> {
          assertThat(regularization.id()).isEqualTo(recordedRegularization);
          assertThat(regularization.resolutionId()).isEqualTo(correction);
          assertThat(regularization.vials()).isEqualTo(2);
        });
      });
    });
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Long.class)).isEqualTo(movementsBefore);
    assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, lot))
        .isEqualTo(depotBefore);

    // V23 no forma parte de este fixture parcial; solo se necesita esta dependencia vacía.
    db.execute("CREATE TABLE app.inventory_installation_reservations "
        + "(institution_id UUID, assignment_id UUID, vial_count INTEGER)");
    var finalizer = new CandidateTransferFinalizationService(db, guard, new DataScope());
    var custodyEvents = new CustodyEventService(db, guard, new DataScope());

    // Composicion solo de prueba; todos los pasos comparten TransactionTemplate.
    var orchestrator = new CandidateReceiptOrchestrator(db, service, candidate, finalizer, guard, new DataScope());
    UUID integratedLot = UUID.randomUUID(), integratedCustody = UUID.randomUUID();
    UUID integratedAssignment = UUID.randomUUID(), rollbackAssignment = UUID.randomUUID();
    UUID deniedAssignment = UUID.randomUUID(), partialAssignment = UUID.randomUUID();
    UUID integratedReceipt = UUID.randomUUID(), integratedClosing = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.createLot(actor, institution, integratedLot, vaccine, "Prueba aislada",
        "INTEGRACION", LocalDate.of(2099, 1, 1), 10));
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), integratedLot, 20, Instant.now(), "Prueba"));
    for (UUID id : List.of(integratedAssignment, rollbackAssignment, deniedAssignment, partialAssignment)) {
      tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), id,
          integratedLot, vaccinator, 5, Instant.now(), "Prueba"));
    }
    long beforeIntegratedMovements = db.queryForObject("SELECT count(*) FROM app.inventory_movements", Long.class);
    var integratedReady = new CountDownLatch(2);
    var integratedStart = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var tasks = java.util.stream.IntStream.range(0, 2).mapToObj(i -> executor.submit(() -> {
        integratedReady.countDown();
        if (!integratedStart.await(20, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        return tx.execute(s -> orchestrator.receive(vaccinator, institution, integratedAssignment,
            integratedReceipt, 5, "", integratedCustody, integratedClosing));
      })).toList();
      assertThat(integratedReady.await(20, TimeUnit.SECONDS)).isTrue();
      integratedStart.countDown();
      assertThat(tasks.get(0).get(20, TimeUnit.SECONDS)).isEqualTo(tasks.get(1).get(20, TimeUnit.SECONDS));
    }
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts WHERE assignment_id=?",
        Integer.class, integratedAssignment)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate WHERE assignment_id=?",
        Integer.class, integratedAssignment)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.transfer_finalizations_candidate WHERE assignment_id=?",
        Integer.class, integratedAssignment)).isEqualTo(1);
    var integratedReview = new CandidateCustodyReviewService(db, guard, new DataScope())
        .review(actor, institution, integratedCustody);
    assertThat(integratedReview.origins()).anySatisfy(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(integratedAssignment);
      assertThat(origin.linkedBy()).isEqualTo(vaccinator);
      assertThat(origin.linkedAt()).isNotNull();
      assertThat(origin.receipts()).extracting(CandidateCustodyReviewService.Receipt::id).containsExactly(integratedReceipt);
      assertThat(origin.finalizations()).singleElement().satisfies(finalization -> {
        assertThat(finalization.id()).isEqualTo(integratedClosing);
        assertThat(finalization.recordedBy()).isEqualTo(vaccinator);
        assertThat(finalization.kind()).isEqualTo("AUTOMATIC");
      });
    });
    UUID integratedReturn = UUID.randomUUID();
    long movementsBeforeReturn = db.queryForObject("SELECT count(*) FROM app.inventory_movements", Long.class);
    int depotBeforeReturn = db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?",
        Integer.class, integratedLot);
    tx.executeWithoutResult(s -> custodyEvents.report(vaccinator, institution, integratedReturn,
        integratedAssignment, 3, "RETURN", "Conteo físico de prueba"));
    tx.executeWithoutResult(s -> custodyEvents.report(vaccinator, institution, integratedReturn,
        integratedAssignment, 3, "RETURN", "Conteo físico de prueba"));
    var reviewAfterReturn = new CandidateCustodyReviewService(db, guard, new DataScope())
        .review(actor, institution, integratedCustody);
    assertThat(reviewAfterReturn.origins()).anySatisfy(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(integratedAssignment);
      assertThat(origin.receipts()).extracting(CandidateCustodyReviewService.Receipt::id)
          .containsExactly(integratedReceipt);
      assertThat(origin.finalizations()).singleElement().satisfies(finalization -> {
        assertThat(finalization.id()).isEqualTo(integratedClosing);
        assertThat(finalization.kind()).isEqualTo("AUTOMATIC");
      });
      assertThat(origin.events()).singleElement().satisfies(event -> {
        assertThat(event.id()).isEqualTo(integratedReturn);
        assertThat(event.status()).isEqualTo("RETURN_PENDING");
        assertThat(event.vials()).isEqualTo(3);
        assertThat(event.reportedBy()).isEqualTo(vaccinator);
        assertThat(event.confirmedBy()).isNull();
        assertThat(event.confirmedAt()).isNull();
      });
    });
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_custody_events WHERE assignment_id=?",
        Integer.class, integratedAssignment)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Long.class))
        .isEqualTo(movementsBeforeReturn);
    assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?",
        Integer.class, integratedLot)).isEqualTo(depotBeforeReturn);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> orchestrator.receive(vaccinator, institution,
        rollbackAssignment, UUID.randomUUID(), 5, "", integratedCustody, integratedClosing)))
        .isInstanceOf(org.springframework.dao.DataIntegrityViolationException.class);
    assertThat(db.queryForObject("SELECT received_vials FROM app.inventory_assignments WHERE id=?", Integer.class, rollbackAssignment)).isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts WHERE assignment_id=?", Integer.class, rollbackAssignment)).isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate WHERE assignment_id=?",
        Integer.class, rollbackAssignment)).isZero();

    org.mockito.Mockito.doReturn(profile, profile)
        .doThrow(new org.springframework.security.access.AccessDeniedException("denegado"))
        .when(guard).require(vaccinator, "ATTENTION_CREATE");
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> orchestrator.receive(vaccinator, institution,
        deniedAssignment, UUID.randomUUID(), 5, "", integratedCustody, UUID.randomUUID())))
        .isInstanceOf(org.springframework.security.access.AccessDeniedException.class);
    org.mockito.Mockito.doReturn(profile).when(guard).require(vaccinator, "ATTENTION_CREATE");
    assertThat(db.queryForObject("SELECT received_vials FROM app.inventory_assignments WHERE id=?", Integer.class, deniedAssignment)).isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts WHERE assignment_id=?", Integer.class, deniedAssignment)).isZero();
    var rejectedProof = new java.util.concurrent.atomic.AtomicReference<CandidateReceiptOrchestrator.ReceiptProof>();
    var failingOrchestrator = new CandidateReceiptOrchestrator(db, service, candidate, finalizer, guard, new DataScope(),
        proof -> { rejectedProof.set(proof); throw new IllegalStateException("Fallo de prueba"); });
    UUID stableReceipt = UUID.randomUUID(), stableFinalization = UUID.randomUUID();
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> failingOrchestrator.receive(vaccinator, institution,
        deniedAssignment, stableReceipt, 5, "", integratedCustody, stableFinalization)))
        .isInstanceOf(IllegalStateException.class).hasMessageContaining("Fallo de prueba");
    assertThat(rejectedProof.get()).isNotNull();
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> candidate.linkFromReceipt(rejectedProof.get())))
        .isInstanceOf(IllegalStateException.class);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts WHERE id=?", Integer.class, stableReceipt)).isZero();
    org.mockito.Mockito.doThrow(new org.springframework.security.access.AccessDeniedException("denegado"))
        .when(guard).require(vaccinator, "INVENTORY_WRITE");
    var issuedProof = new java.util.concurrent.atomic.AtomicReference<CandidateReceiptOrchestrator.ReceiptProof>();
    var observingOrchestrator = new CandidateReceiptOrchestrator(db, service, candidate, finalizer,
        guard, new DataScope(), issuedProof::set);
    var confirmed = tx.execute(s -> observingOrchestrator.receive(vaccinator, institution, deniedAssignment,
        stableReceipt, 5, "", integratedCustody, stableFinalization));
    var confirmedRetry = tx.execute(s -> orchestrator.receive(vaccinator, institution, deniedAssignment,
        stableReceipt, 5, "", integratedCustody, stableFinalization));
    assertThat(confirmedRetry).isEqualTo(confirmed);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> candidate.linkFromReceipt(issuedProof.get())))
        .isInstanceOf(IllegalStateException.class);
    assertThat(db.queryForObject("SELECT linked_by FROM app.individual_custody_origins_candidate WHERE assignment_id=?",
        UUID.class, deniedAssignment)).isEqualTo(vaccinator);
    org.mockito.Mockito.verify(guard, org.mockito.Mockito.never()).require(vaccinator, "INVENTORY_WRITE");
    tx.executeWithoutResult(s -> orchestrator.receive(vaccinator, institution, partialAssignment,
        UUID.randomUUID(), 3, "Diferencia", integratedCustody, UUID.randomUUID()));
    tx.executeWithoutResult(s -> orchestrator.receive(vaccinator, institution, partialAssignment,
        UUID.randomUUID(), 2, "", integratedCustody, UUID.randomUUID()));
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts WHERE assignment_id=?", Integer.class, partialAssignment)).isEqualTo(2);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate WHERE assignment_id=?", Integer.class, partialAssignment)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.transfer_finalizations_candidate WHERE assignment_id=?", Integer.class, partialAssignment)).isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Long.class)).isEqualTo(beforeIntegratedMovements);
    assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, integratedLot)).isZero();
    UUID partialTransfer = UUID.randomUUID(), fullTransfer = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, UUID.randomUUID(), lot, 20, Instant.now(), "Prueba"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), partialTransfer, lot, vaccinator, 10, Instant.now(), "Prueba"));
    tx.executeWithoutResult(s -> service.dispatch(actor, institution, UUID.randomUUID(), fullTransfer, lot, vaccinator, 10, Instant.now(), "Prueba"));
    tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, partialTransfer, UUID.randomUUID(), 8, "Diferencia"));
    tx.executeWithoutResult(s -> service.receivePartial(vaccinator, institution, fullTransfer, UUID.randomUUID(), 10, ""));
    UUID partialFinalization = UUID.randomUUID(), complement = UUID.randomUUID();
    long beforeFinalizationMovements = db.queryForObject("SELECT count(*) FROM app.inventory_movements", Long.class);
    var receptionReady = new CountDownLatch(2);
    var receptionStart = new CountDownLatch(1);
    try (var executor = Executors.newFixedThreadPool(2)) {
      var receptionTask = executor.submit(() -> {
        receptionReady.countDown();
        if (!receptionStart.await(20, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        return tx.execute(s -> service.receivePartial(vaccinator, institution, partialTransfer, complement, 2, ""));
      });
      var finalizationTask = executor.submit(() -> {
        receptionReady.countDown();
        if (!receptionStart.await(20, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        try {
          tx.executeWithoutResult(s -> finalizer.finalizeTransfer(actor, institution, partialTransfer,
              partialFinalization, true, "Revision de recepcion complementaria"));
          return true;
        } catch (IllegalArgumentException ex) { return false; }
      });
      assertThat(receptionReady.await(20, TimeUnit.SECONDS)).isTrue();
      receptionStart.countDown();
      assertThat(receptionTask.get(20, TimeUnit.SECONDS).receivedVials()).isEqualTo(10);
      boolean finalized = finalizationTask.get(20, TimeUnit.SECONDS);
      if (!finalized) tx.executeWithoutResult(s -> finalizer.finalizeTransfer(actor, institution, partialTransfer,
          partialFinalization, true, "Revision de recepcion complementaria"));
    }
    UUID partialReplay = tx.execute(s -> finalizer.finalizeTransfer(actor, institution, partialTransfer,
        partialFinalization, true, "Revision de recepcion complementaria"));
    assertThat(partialReplay).isEqualTo(partialFinalization);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts WHERE assignment_id=?",
        Integer.class, partialTransfer)).isEqualTo(2);
    assertThat(db.queryForObject("SELECT count(*) FROM app.transfer_finalizations_candidate WHERE assignment_id=?",
        Integer.class, partialTransfer)).isEqualTo(1);

    UUID pendingReturn = UUID.randomUUID(), autoFinalization = UUID.randomUUID();
    var eventReady = new CountDownLatch(2);
    var eventStart = new CountDownLatch(1);
    boolean automaticSucceeded;
    try (var executor = Executors.newFixedThreadPool(2)) {
      var eventTask = executor.submit(() -> {
        eventReady.countDown();
        if (!eventStart.await(20, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        tx.executeWithoutResult(s -> custodyEvents.report(vaccinator, institution, pendingReturn,
            fullTransfer, 2, "RETURN", "Devolucion pendiente"));
        return true;
      });
      var automaticTask = executor.submit(() -> {
        eventReady.countDown();
        if (!eventStart.await(20, TimeUnit.SECONDS)) throw new AssertionError("Inicio agotado");
        try {
          tx.executeWithoutResult(s -> finalizer.finalizeTransfer(vaccinator, institution, fullTransfer,
              autoFinalization, false, ""));
          return true;
        } catch (IllegalArgumentException ex) { return false; }
      });
      assertThat(eventReady.await(20, TimeUnit.SECONDS)).isTrue();
      eventStart.countDown();
      assertThat(eventTask.get(20, TimeUnit.SECONDS)).isTrue();
      automaticSucceeded = automaticTask.get(20, TimeUnit.SECONDS);
    }
    if (!automaticSucceeded) tx.executeWithoutResult(s -> finalizer.finalizeTransfer(actor, institution, fullTransfer,
        UUID.randomUUID(), true, "Devolucion pendiente de recepcion"));
    assertThat(db.queryForObject("SELECT status FROM app.inventory_custody_events WHERE id=?",
        String.class, pendingReturn)).isEqualTo("RETURN_PENDING");
    assertThat(service.listPendingFollowUps(actor, institution)).anySatisfy(item -> {
      assertThat(item.id()).isEqualTo(pendingReturn);
      assertThat(item.kind()).isEqualTo("RETURN_PENDING");
      assertThat(item.pendingVials()).isEqualTo(2);
    });
    assertThat(db.queryForObject("SELECT count(*) FROM app.transfer_finalizations_candidate WHERE assignment_id=?",
        Integer.class, fullTransfer)).isEqualTo(1);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Long.class)).isEqualTo(beforeFinalizationMovements);
    assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE id=?", Integer.class, lot)).isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate WHERE custody_id=?",
        Integer.class, candidateCustody)).isEqualTo(2);
  }
}
