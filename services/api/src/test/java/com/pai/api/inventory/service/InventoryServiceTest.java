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
import java.time.LocalDate;
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
  private CampaignService campaigns;
  private CustodyEventService custody;
  private InstallationReservationService reservations;
  private final UUID institution = UUID.randomUUID();
  private final UUID actor = UUID.randomUUID();
  private final UUID vaccinator = UUID.randomUUID();
  private final UUID lot = UUID.randomUUID();
  private final UUID vaccine = UUID.randomUUID();
  private final Instant now = Instant.parse("2026-01-01T12:00:00Z");

  @BeforeEach
  void setUp() {
    var source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
        + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1;LOCK_TIMEOUT=10000", "sa", "");
    db = new JdbcTemplate(source);
    tx = new TransactionTemplate(new DataSourceTransactionManager(source));
    // Esquema minimo compatible con las consultas; V20 debe probarse aparte en PostgreSQL.
    db.execute("CREATE SCHEMA app");
    db.execute("CREATE TABLE app.vaccines (id UUID PRIMARY KEY, name VARCHAR)");
    db.execute("CREATE TABLE app.users (id UUID PRIMARY KEY, institution_id UUID, status VARCHAR, full_name VARCHAR)");
    db.execute("CREATE TABLE app.roles (id UUID PRIMARY KEY, code VARCHAR)");
    db.execute("CREATE TABLE app.user_roles (user_id UUID, role_id UUID)");
    db.execute("CREATE TABLE app.inventory_lots (id UUID PRIMARY KEY, institution_id UUID, vaccine_id UUID, "
        + "manufacturer VARCHAR, lot_number VARCHAR, expires_on DATE, doses_per_vial INT, "
        + "available_vials INT DEFAULT 0 CHECK (available_vials >= 0), created_by UUID)");
    db.execute("CREATE TABLE app.inventory_assignments (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, "
        + "vaccinator_id UUID, vial_count INT, status VARCHAR, dispatched_by UUID, "
        + "dispatched_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, received_at TIMESTAMP WITH TIME ZONE, campaign_id UUID)");
    db.execute("CREATE TABLE app.inventory_campaigns (id UUID PRIMARY KEY, institution_id UUID, name VARCHAR, location VARCHAR, "
        + "starts_on DATE, ends_on DATE, status VARCHAR, created_by UUID, finished_by UUID, finished_at TIMESTAMP WITH TIME ZONE)");
    db.execute("CREATE TABLE app.inventory_campaign_participants (institution_id UUID, campaign_id UUID, vaccinator_id UUID, "
        + "added_by UUID, PRIMARY KEY(campaign_id, vaccinator_id))");
    db.execute("CREATE TABLE app.inventory_movements (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, "
        + "assignment_id UUID, kind VARCHAR, vial_count INT, occurred_at TIMESTAMP WITH TIME ZONE, "
        + "recorded_by UUID, note VARCHAR)");
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
    var guard = mock(PermissionGuard.class);
    var actorProfile = mock(AuthorizedUser.class);
    var institutionProfile = mock(InstitutionEntity.class);
    when(institutionProfile.getId()).thenReturn(institution);
    when(actorProfile.getInstitution()).thenReturn(institutionProfile);
    when(actorProfile.getPermissions()).thenReturn(List.of("INVENTORY_READ", "INVENTORY_WRITE"));
    when(actorProfile.getRoles()).thenReturn(List.of("VACCINATOR"));
    when(guard.require(any(), any())).thenReturn(actorProfile);
    service = new InventoryService(db, guard, new DataScope());
    campaigns = new CampaignService(db, guard, new DataScope());
    custody = new CustodyEventService(db, guard, new DataScope());
    reservations = new InstallationReservationService(db, guard, new DataScope());
    tx.executeWithoutResult(s -> service.createLot(actor, institution, lot, vaccine,
        "Fabricante", "Lote-1", LocalDate.of(2028, 1, 1), 10));
  }

  @Test
  void newLotAndEntryCommitTogetherAndRollbackOnDuplicateMovement() {
    UUID movement = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, movement, lot, 1, now, "Conteo"));
    UUID newLot = UUID.randomUUID();
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.createLotWithEntry(actor, institution,
        newLot, vaccine, "Fabricante", "Nuevo", LocalDate.of(2028, 1, 1), 10,
        movement, 5, now, "Entrada"))).isInstanceOf(DataIntegrityViolationException.class);
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
  void entryIsRecordedAndRetryRollsBackWithoutDuplicatingBalance() {
    UUID movement = UUID.randomUUID();
    tx.executeWithoutResult(s -> service.recordEntry(actor, institution, movement, lot, 10, now, "Conteo inicial"));
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.recordEntry(
        actor, institution, movement, lot, 10, now, "Conteo inicial")))
        .isInstanceOf(DataIntegrityViolationException.class);
    assertThat(service.listLots(actor, institution).getFirst().availableVials()).isEqualTo(10);
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
        .isInstanceOf(DataIntegrityViolationException.class);
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
