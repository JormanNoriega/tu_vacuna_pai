package com.pai.api.inventory.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.transaction.support.TransactionTemplate;

/** Prototipo H2 exclusivamente: no valida PostgreSQL ni crea esquema operativo. */
class IndividualCustodySchemaDesignTest {
  private final UUID institution = UUID.randomUUID(), otherInstitution = UUID.randomUUID();
  private final UUID user = UUID.randomUUID(), otherUser = UUID.randomUUID(), actor = UUID.randomUUID();
  private final UUID lot = UUID.randomUUID(), otherLot = UUID.randomUUID(), custody = UUID.randomUUID();
  private final UUID assignment = UUID.randomUUID(), receipt = UUID.randomUUID(), event = UUID.randomUUID();
  private JdbcTemplate db;
  private TransactionTemplate tx;

  @BeforeEach
  void setUp() {
    var source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
        + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1", "sa", "");
    db = new JdbcTemplate(source);
    tx = new TransactionTemplate(new DataSourceTransactionManager(source));
    db.execute("CREATE SCHEMA app");
    db.execute("CREATE TABLE app.users (id UUID PRIMARY KEY)");
    db.execute("CREATE TABLE app.inventory_lots (id UUID PRIMARY KEY, institution_id UUID NOT NULL, "
        + "UNIQUE(institution_id,id))");
    db.execute("CREATE TABLE app.inventory_assignments (id UUID PRIMARY KEY, institution_id UUID NOT NULL, "
        + "lot_id UUID NOT NULL, vaccinator_id UUID NOT NULL, received_vials INT NOT NULL, status VARCHAR NOT NULL)");
    db.execute("CREATE TABLE app.inventory_receipts (id UUID PRIMARY KEY, assignment_id UUID NOT NULL, vials INT NOT NULL)");
    db.execute("CREATE TABLE app.inventory_custody_events (id UUID PRIMARY KEY, assignment_id UUID NOT NULL, "
        + "vials INT NOT NULL, status VARCHAR NOT NULL)");
    new ResourceDatabasePopulator(new ClassPathResource("inventory/individual_custody_candidate.sql")).execute(source);
    for (var id : new UUID[] {user, otherUser, actor}) db.update("INSERT INTO app.users VALUES (?)", id);
    db.update("INSERT INTO app.inventory_lots VALUES (?, ?)", lot, institution);
    db.update("INSERT INTO app.inventory_lots VALUES (?, ?)", otherLot, institution);
    db.update("INSERT INTO app.inventory_assignments VALUES (?, ?, ?, ?, 8, 'PARTIALLY_RECEIVED')",
        assignment, institution, lot, user);
    db.update("INSERT INTO app.inventory_receipts VALUES (?, ?, 8)", receipt, assignment);
    db.update("INSERT INTO app.inventory_custody_events VALUES (?, ?, 3, 'RETURN_PENDING')", event, assignment);
  }

  private void createCustody(UUID id, UUID inst, UUID lotId, UUID person) {
    db.update("INSERT INTO app.individual_custodies_candidate (id, institution_id, lot_id, custodian_id, created_by) "
        + "VALUES (?, ?, ?, ?, ?)", id, inst, lotId, person, actor);
  }

  private void link(UUID id, UUID inst, UUID lotId, UUID person, UUID cust) {
    db.update("INSERT INTO app.individual_custody_origins_candidate "
        + "(assignment_id, institution_id, lot_id, custodian_id, custody_id, linked_by) VALUES (?, ?, ?, ?, ?, ?)",
        id, inst, lotId, person, cust, actor);
  }

  @Test
  void linkedAssignmentRetainsOriginalReceiptAndEventWithoutCreatingMovementsOrBalances() {
    createCustody(custody, institution, lot, user);
    link(assignment, institution, lot, user, custody);
    assertThat(db.queryForObject("SELECT r.id FROM app.individual_custody_origins_candidate o "
        + "JOIN app.inventory_receipts r ON r.assignment_id=o.assignment_id WHERE o.custody_id=?",
        UUID.class, custody)).isEqualTo(receipt);
    assertThat(db.queryForObject("SELECT e.id FROM app.individual_custody_origins_candidate o "
        + "JOIN app.inventory_custody_events e ON e.assignment_id=o.assignment_id WHERE o.custody_id=?",
        UUID.class, custody)).isEqualTo(event);
    assertThat(db.queryForObject("SELECT status FROM app.inventory_custody_events WHERE id=?", String.class, event))
        .isEqualTo("RETURN_PENDING");
    assertThat(db.queryForObject("SELECT count(*) FROM information_schema.columns WHERE table_schema='APP' "
        + "AND table_name='INDIVIDUAL_CUSTODIES_CANDIDATE' AND column_name IN ('BALANCE','AVAILABLE_VIALS')",
        Integer.class)).isZero();
  }

  @Test
  void rejectsCrossInstitutionLotOwnerAndDuplicateOrigin() {
    createCustody(custody, institution, lot, user);
    assertThatThrownBy(() -> link(assignment, otherInstitution, lot, user, custody))
        .isInstanceOf(DataIntegrityViolationException.class);
    assertThatThrownBy(() -> link(assignment, institution, otherLot, user, custody))
        .isInstanceOf(DataIntegrityViolationException.class);
    assertThatThrownBy(() -> link(assignment, institution, lot, otherUser, custody))
        .isInstanceOf(DataIntegrityViolationException.class);
    link(assignment, institution, lot, user, custody);
    assertThatThrownBy(() -> link(assignment, institution, lot, user, custody))
        .isInstanceOf(DataIntegrityViolationException.class);
    assertThatThrownBy(() -> createCustody(UUID.randomUUID(), institution, lot, user))
        .isInstanceOf(DataIntegrityViolationException.class);
  }

  @Test
  void multipleAssignmentsCanShareCustodyWithoutInventingReceiptForHistoricalAssignment() {
    UUID historical = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_assignments VALUES (?, ?, ?, ?, 5, 'RECEIVED')",
        historical, institution, lot, user);
    createCustody(custody, institution, lot, user);
    link(assignment, institution, lot, user, custody);
    link(historical, institution, lot, user, custody);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custody_origins_candidate WHERE custody_id=?",
        Integer.class, custody)).isEqualTo(2);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts WHERE assignment_id=?",
        Integer.class, historical)).isZero();
  }

  @Test
  void failedLinkRollsBackCustodyCreation() {
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> {
      createCustody(custody, institution, lot, user);
      link(UUID.randomUUID(), institution, lot, user, custody);
    })).isInstanceOf(DataIntegrityViolationException.class);
    assertThat(db.queryForObject("SELECT count(*) FROM app.individual_custodies_candidate WHERE id=?",
        Integer.class, custody)).isZero();
  }
}
