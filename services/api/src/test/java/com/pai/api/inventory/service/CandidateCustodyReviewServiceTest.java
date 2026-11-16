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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.security.access.AccessDeniedException;

class CandidateCustodyReviewServiceTest {
  private final UUID institution = UUID.randomUUID(), actor = UUID.randomUUID(), user = UUID.randomUUID();
  private final UUID lot = UUID.randomUUID(), custody = UUID.randomUUID();
  private final UUID first = UUID.randomUUID(), second = UUID.randomUUID();
  private final UUID receipt1 = UUID.randomUUID(), receipt2 = UUID.randomUUID(), event = UUID.randomUUID();
  private final UUID correction = UUID.randomUUID(), regularization = UUID.randomUUID(), loss = UUID.randomUUID();
  private JdbcTemplate db;
  private PermissionGuard guard;
  private CandidateCustodyReviewService service;

  @BeforeEach
  void setUp() {
    var source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
        + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1", "sa", "");
    db = new JdbcTemplate(source);
    db.execute("CREATE SCHEMA app");
    db.execute("CREATE TABLE app.users (id UUID PRIMARY KEY)");
    db.execute("CREATE TABLE app.inventory_lots (id UUID PRIMARY KEY, institution_id UUID NOT NULL, UNIQUE(institution_id,id))");
    db.execute("CREATE TABLE app.inventory_assignments (id UUID PRIMARY KEY, institution_id UUID NOT NULL, "
        + "lot_id UUID NOT NULL, vaccinator_id UUID NOT NULL, vial_count INT, received_vials INT, status VARCHAR, "
        + "UNIQUE(institution_id,lot_id,id))");
    db.execute("CREATE TABLE app.inventory_receipts (id UUID PRIMARY KEY, institution_id UUID, assignment_id UUID, "
        + "lot_id UUID, vials INT, received_by UUID, received_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, difference_note VARCHAR)");
    db.execute("CREATE TABLE app.inventory_custody_events (id UUID PRIMARY KEY, institution_id UUID, assignment_id UUID, "
        + "lot_id UUID, vial_count INT, status VARCHAR, reported_by UUID, reported_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, "
        + "report_note VARCHAR, confirmed_by UUID, confirmed_at TIMESTAMP WITH TIME ZONE, confirmation_note VARCHAR)");
    db.execute("CREATE TABLE app.inventory_movements (id UUID PRIMARY KEY)");
    db.execute("CREATE TABLE app.inventory_difference_resolutions (id UUID PRIMARY KEY, institution_id UUID, "
        + "assignment_id UUID, lot_id UUID, vial_count INT, kind VARCHAR, recorded_by UUID, "
        + "recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, note VARCHAR)");
    db.execute("CREATE TABLE app.inventory_depot_regularizations (id UUID PRIMARY KEY, institution_id UUID, "
        + "resolution_id UUID, vial_count INT, recorded_by UUID, recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, note VARCHAR)");
    new ResourceDatabasePopulator(new ClassPathResource("inventory/individual_custody_candidate.sql"),
        new ClassPathResource("inventory/transfer_finalization_candidate.sql")).execute(source);
    db.update("INSERT INTO app.users VALUES (?)", actor);
    db.update("INSERT INTO app.users VALUES (?)", user);
    db.update("INSERT INTO app.inventory_lots VALUES (?,?)", lot, institution);
    db.update("INSERT INTO app.inventory_assignments VALUES (?,?,?,?,10,8,'PARTIALLY_RECEIVED')", first, institution, lot, user);
    db.update("INSERT INTO app.inventory_assignments VALUES (?,?,?,?,5,5,'RECEIVED')", second, institution, lot, user);
    db.update("INSERT INTO app.inventory_receipts (id,institution_id,assignment_id,lot_id,vials,received_by,difference_note) "
        + "VALUES (?,?,?,?,8,?,'Faltante')", receipt1, institution, first, lot, user);
    db.update("INSERT INTO app.inventory_receipts (id,institution_id,assignment_id,lot_id,vials,received_by,difference_note) "
        + "VALUES (?,?,?,?,5,?,'')", receipt2, institution, second, lot, user);
    db.update("INSERT INTO app.inventory_custody_events (id,institution_id,assignment_id,lot_id,vial_count,status,reported_by,report_note) "
        + "VALUES (?,?,?,?,3,'RETURN_PENDING',?,'Conteo')", event, institution, first, lot, user);
    db.update("INSERT INTO app.inventory_difference_resolutions (id,institution_id,assignment_id,lot_id,vial_count,kind,recorded_by,note) "
        + "VALUES (?,?,?,?,2,'DISPATCH_CORRECTION',?,'Acta')", correction, institution, first, lot, actor);
    db.update("INSERT INTO app.inventory_depot_regularizations (id,institution_id,resolution_id,vial_count,recorded_by,note) "
        + "VALUES (?,?,?,1,?,'Conteo en depósito')", regularization, institution, correction, actor);
    db.update("INSERT INTO app.inventory_difference_resolutions (id,institution_id,assignment_id,lot_id,vial_count,kind,recorded_by,note) "
        + "VALUES (?,?,?,?,1,'LOST',?,'Investigación')", loss, institution, second, lot, actor);
    db.update("INSERT INTO app.individual_custodies_candidate (id,institution_id,lot_id,custodian_id,created_by) VALUES (?,?,?,?,?)",
        custody, institution, lot, user, actor);
    for (var id : List.of(first, second))
      db.update("INSERT INTO app.individual_custody_origins_candidate "
          + "(assignment_id,institution_id,lot_id,custodian_id,custody_id,linked_by) VALUES (?,?,?,?,?,?)",
          id, institution, lot, user, custody, actor);
    guard = mock(PermissionGuard.class);
    var profile = mock(AuthorizedUser.class);
    var inst = mock(InstitutionEntity.class);
    when(inst.getId()).thenReturn(institution);
    when(profile.getInstitution()).thenReturn(inst);
    when(profile.getPermissions()).thenReturn(List.of("INVENTORY_READ"));
    when(guard.require(any(), any())).thenReturn(profile);
    service = new CandidateCustodyReviewService(db, guard, new DataScope());
  }

  @Test
  void preservesMultipleDeliveriesAndTheirEvidenceWithoutInventingAllocation() {
    var result = service.review(actor, institution, custody);
    assertThat(result.custodianId()).isEqualTo(user);
    assertThat(result.origins()).hasSize(2);
    assertThat(result.origins()).anySatisfy(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(first);
      assertThat(origin.linkedBy()).isEqualTo(actor);
      assertThat(origin.linkedAt()).isNotNull();
      assertThat(origin.receipts()).extracting(CandidateCustodyReviewService.Receipt::id).containsExactly(receipt1);
      assertThat(origin.events()).singleElement().satisfies(item -> {
        assertThat(item.id()).isEqualTo(event);
        assertThat(item.status()).isEqualTo("RETURN_PENDING");
        assertThat(item.note()).isEqualTo("Conteo");
      });
      assertThat(origin.resolutions()).singleElement().satisfies(item -> {
        assertThat(item.id()).isEqualTo(correction);
        assertThat(item.kind()).isEqualTo("DISPATCH_CORRECTION");
        assertThat(item.note()).isEqualTo("Acta");
        assertThat(item.regularizations()).singleElement().satisfies(regularized -> {
          assertThat(regularized.id()).isEqualTo(regularization);
          assertThat(regularized.resolutionId()).isEqualTo(correction);
          assertThat(regularized.vials()).isEqualTo(1);
          assertThat(regularized.note()).isEqualTo("Conteo en depósito");
        });
      });
    });
    assertThat(result.origins()).anySatisfy(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(second);
      assertThat(origin.receipts()).extracting(CandidateCustodyReviewService.Receipt::id).containsExactly(receipt2);
      assertThat(origin.events()).isEmpty();
      assertThat(origin.resolutions()).singleElement().satisfies(item -> {
        assertThat(item.id()).isEqualTo(loss);
        assertThat(item.regularizations()).isEmpty();
      });
    });
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_custody_events", Integer.class)).isEqualTo(1);
  }

  @Test
  void multipleReceiptsAndEventsAreNotMultipliedByTheQuery() {
    UUID extraReceipt = UUID.randomUUID(), extraEvent = UUID.randomUUID(), extraRegularization = UUID.randomUUID();
    db.update("UPDATE app.inventory_receipts SET vials=7 WHERE id=?", receipt1);
    db.update("INSERT INTO app.inventory_receipts (id,institution_id,assignment_id,lot_id,vials,received_by,difference_note) "
        + "VALUES (?,?,?,?,1,?,'Complementaria')", extraReceipt, institution, first, lot, user);
    db.update("INSERT INTO app.inventory_custody_events (id,institution_id,assignment_id,lot_id,vial_count,status,reported_by,report_note) "
        + "VALUES (?,?,?,?,1,'INCIDENT_LOST',?,'Acta')", extraEvent, institution, first, lot, user);
    db.update("INSERT INTO app.inventory_depot_regularizations (id,institution_id,resolution_id,vial_count,recorded_by,note) "
        + "VALUES (?,?,?,1,?,'Segundo conteo')", extraRegularization, institution, correction, actor);
    var result = service.review(actor, institution, custody);
    assertThat(result.origins()).anySatisfy(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(first);
      assertThat(origin.receipts()).extracting(CandidateCustodyReviewService.Receipt::id)
          .containsExactlyInAnyOrder(receipt1, extraReceipt);
      assertThat(origin.events()).extracting(CandidateCustodyReviewService.Event::id)
          .containsExactlyInAnyOrder(event, extraEvent);
      assertThat(origin.resolutions()).singleElement().satisfies(resolution ->
          assertThat(resolution.regularizations()).extracting(CandidateCustodyReviewService.Regularization::id)
              .containsExactlyInAnyOrder(regularization, extraRegularization));
    });
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isZero();
  }

  @Test
  void preventsCrossInstitutionAndRequiresReadPermission() {
    assertThatThrownBy(() -> service.review(actor, UUID.randomUUID(), custody)).isInstanceOf(ScopeViolationException.class);
    assertThatThrownBy(() -> service.review(actor, institution, UUID.randomUUID())).isInstanceOf(IllegalArgumentException.class);
    when(guard.require(actor, "INVENTORY_READ")).thenThrow(new AccessDeniedException("denegado"));
    assertThatThrownBy(() -> service.review(actor, institution, custody)).isInstanceOf(AccessDeniedException.class);
  }

  @Test
  void reviewExcludesOtherCustodiesAndCrossInstitutionEvidenceWithoutWriting() {
    UUID otherInstitution = UUID.randomUUID(), otherLot = UUID.randomUUID();
    UUID otherCustody = UUID.randomUUID(), otherAssignment = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_lots VALUES (?,?)", otherLot, institution);
    db.update("INSERT INTO app.inventory_assignments VALUES (?,?,?,?,1,1,'RECEIVED')",
        otherAssignment, institution, otherLot, user);
    db.update("INSERT INTO app.individual_custodies_candidate "
        + "(id,institution_id,lot_id,custodian_id,created_by) VALUES (?,?,?,?,?)",
        otherCustody, institution, otherLot, user, actor);
    db.update("INSERT INTO app.individual_custody_origins_candidate "
        + "(assignment_id,institution_id,lot_id,custodian_id,custody_id,linked_by) VALUES (?,?,?,?,?,?)",
        otherAssignment, institution, otherLot, user, otherCustody, actor);
    // Filas inconsistentes deliberadas: este fixture mínimo no implementa todas las FK reales.
    db.update("INSERT INTO app.inventory_receipts (id,institution_id,assignment_id,lot_id,vials,received_by,difference_note) "
        + "VALUES (?,?,?,?,1,?,'Ajena')", UUID.randomUUID(), otherInstitution, first, lot, user);
    db.update("INSERT INTO app.inventory_custody_events (id,institution_id,assignment_id,lot_id,vial_count,status,reported_by,report_note) "
        + "VALUES (?,?,?,?,1,'RETURN_PENDING',?,'Ajena')", UUID.randomUUID(), otherInstitution, first, lot, user);
    db.update("INSERT INTO app.inventory_difference_resolutions (id,institution_id,assignment_id,lot_id,vial_count,kind,recorded_by,note) "
        + "VALUES (?,?,?,?,1,'LOST',?,'Ajena')", UUID.randomUUID(), otherInstitution, first, lot, actor);
    db.update("INSERT INTO app.inventory_depot_regularizations (id,institution_id,resolution_id,vial_count,recorded_by,note) "
        + "VALUES (?,?,?,1,?,'Ajena')", UUID.randomUUID(), otherInstitution, correction, actor);
    var before = snapshot();

    var review = service.review(actor, institution, custody);
    assertThat(review.origins()).extracting(CandidateCustodyReviewService.Origin::assignmentId)
        .containsExactlyInAnyOrder(first, second);
    assertThat(review.origins()).anySatisfy(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(first);
      assertThat(origin.receipts()).extracting(CandidateCustodyReviewService.Receipt::id).containsExactly(receipt1);
      assertThat(origin.events()).extracting(CandidateCustodyReviewService.Event::id).containsExactly(event);
      assertThat(origin.resolutions()).singleElement().satisfies(resolution -> {
        assertThat(resolution.id()).isEqualTo(correction);
        assertThat(resolution.regularizations()).extracting(CandidateCustodyReviewService.Regularization::id)
            .containsExactly(regularization);
      });
    });
    assertThat(snapshot()).isEqualTo(before);
  }

  @Test
  void finalizationIsAttachedToItsDeliveryAndDoesNotErasePendingFollowUp() {
    UUID finalization = UUID.randomUUID();
    db.update("INSERT INTO app.transfer_finalizations_candidate "
        + "(id,institution_id,assignment_id,lot_id,kind,recorded_by,evidence) VALUES (?,?,?,?,'ADMIN_REVIEW',?,?)",
        finalization, institution, first, lot, actor, "Ubicación por verificar");
    var before = snapshot();
    var review = service.review(actor, institution, custody);
    assertThat(review.origins()).anySatisfy(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(first);
      assertThat(origin.finalizations()).singleElement().satisfies(item -> {
        assertThat(item.id()).isEqualTo(finalization);
        assertThat(item.lotId()).isEqualTo(lot);
        assertThat(item.kind()).isEqualTo("ADMIN_REVIEW");
        assertThat(item.recordedBy()).isEqualTo(actor);
        assertThat(item.recordedAt()).isNotNull();
        assertThat(item.evidence()).isEqualTo("Ubicación por verificar");
      });
      assertThat(origin.events()).singleElement().satisfies(item -> {
        assertThat(item.id()).isEqualTo(event);
        assertThat(item.status()).isEqualTo("RETURN_PENDING");
      });
      assertThat(origin.resolutions()).singleElement().satisfies(item ->
          assertThat(item.regularizations()).singleElement().satisfies(reg ->
              assertThat(reg.id()).isEqualTo(regularization)));
    });
    assertThat(review.origins()).anySatisfy(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(second);
      assertThat(origin.finalizations()).isEmpty();
    });
    assertThat(snapshot()).isEqualTo(before);
  }

  @Test
  void eachDeliveryKeepsItsOwnLinkActorAndTimestamp() {
    var firstTime = java.time.Instant.parse("2026-01-01T09:00:00Z");
    var secondTime = java.time.Instant.parse("2026-01-02T10:00:00Z");
    db.update("UPDATE app.individual_custody_origins_candidate SET linked_by=?, linked_at=? WHERE assignment_id=?",
        actor, java.sql.Timestamp.from(firstTime), first);
    db.update("UPDATE app.individual_custody_origins_candidate SET linked_by=?, linked_at=? WHERE assignment_id=?",
        user, java.sql.Timestamp.from(secondTime), second);
    var before = snapshot();
    var result = service.review(actor, institution, custody);
    assertThat(result.origins()).anySatisfy(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(first);
      assertThat(origin.linkedBy()).isEqualTo(actor);
      assertThat(origin.linkedAt()).isEqualTo(firstTime);
    });
    assertThat(result.origins()).anySatisfy(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(second);
      assertThat(origin.linkedBy()).isEqualTo(user);
      assertThat(origin.linkedAt()).isEqualTo(secondTime);
    });
    assertThat(snapshot()).isEqualTo(before);
  }

  @Test
  void sameVaccinatorDifferentLotsKeepTheirOwnCompleteEvidence() {
    UUID otherLot = UUID.randomUUID(), otherCustody = UUID.randomUUID(), otherAssignment = UUID.randomUUID();
    UUID otherReceipt = UUID.randomUUID(), otherEvent = UUID.randomUUID(), otherResolution = UUID.randomUUID();
    UUID otherRegularization = UUID.randomUUID(), otherFinalization = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_lots VALUES (?,?)", otherLot, institution);
    db.update("INSERT INTO app.inventory_assignments VALUES (?,?,?,?,4,3,'CLOSED_WITH_DIFFERENCE')",
        otherAssignment, institution, otherLot, user);
    db.update("INSERT INTO app.individual_custodies_candidate "
        + "(id,institution_id,lot_id,custodian_id,created_by) VALUES (?,?,?,?,?)",
        otherCustody, institution, otherLot, user, actor);
    db.update("INSERT INTO app.individual_custody_origins_candidate "
        + "(assignment_id,institution_id,lot_id,custodian_id,custody_id,linked_by) VALUES (?,?,?,?,?,?)",
        otherAssignment, institution, otherLot, user, otherCustody, user);
    db.update("INSERT INTO app.inventory_receipts (id,institution_id,assignment_id,lot_id,vials,received_by,difference_note) "
        + "VALUES (?,?,?,?,3,?,'Diferencia')", otherReceipt, institution, otherAssignment, otherLot, user);
    db.update("INSERT INTO app.inventory_custody_events (id,institution_id,assignment_id,lot_id,vial_count,status,reported_by,report_note) "
        + "VALUES (?,?,?,?,1,'RETURN_PENDING',?,'Pendiente')", otherEvent, institution, otherAssignment, otherLot, user);
    db.update("INSERT INTO app.inventory_difference_resolutions (id,institution_id,assignment_id,lot_id,vial_count,kind,recorded_by,note) "
        + "VALUES (?,?,?,?,1,'DISPATCH_CORRECTION',?,'Acta')", otherResolution, institution, otherAssignment, otherLot, actor);
    db.update("INSERT INTO app.inventory_depot_regularizations (id,institution_id,resolution_id,vial_count,recorded_by,note) "
        + "VALUES (?,?,?,1,?,'Conteo')", otherRegularization, institution, otherResolution, actor);
    db.update("INSERT INTO app.transfer_finalizations_candidate "
        + "(id,institution_id,assignment_id,lot_id,kind,recorded_by,evidence) VALUES (?,?,?,?,'ADMIN_REVIEW',?,'Acta')",
        otherFinalization, institution, otherAssignment, otherLot, actor);
    var before = snapshot();

    var original = service.review(actor, institution, custody);
    var other = service.review(actor, institution, otherCustody);
    assertThat(original.custodianId()).isEqualTo(other.custodianId()).isEqualTo(user);
    assertThat(original.lotId()).isEqualTo(lot);
    assertThat(original.origins()).extracting(CandidateCustodyReviewService.Origin::assignmentId)
        .containsExactlyInAnyOrder(first, second);
    assertThat(other.lotId()).isEqualTo(otherLot);
    assertThat(other.origins()).singleElement().satisfies(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(otherAssignment);
      assertThat(origin.linkedBy()).isEqualTo(user);
      assertThat(origin.receipts()).extracting(CandidateCustodyReviewService.Receipt::id).containsExactly(otherReceipt);
      assertThat(origin.events()).extracting(CandidateCustodyReviewService.Event::id).containsExactly(otherEvent);
      assertThat(origin.resolutions()).singleElement().satisfies(resolution -> {
        assertThat(resolution.id()).isEqualTo(otherResolution);
        assertThat(resolution.regularizations()).extracting(CandidateCustodyReviewService.Regularization::id)
            .containsExactly(otherRegularization);
      });
      assertThat(origin.finalizations()).extracting(CandidateCustodyReviewService.Finalization::id)
          .containsExactly(otherFinalization);
    });
    assertThat(snapshot()).isEqualTo(before);
  }

  private List<List<java.util.Map<String, Object>>> snapshot() {
    return List.of("inventory_lots", "inventory_assignments", "inventory_receipts",
        "inventory_custody_events", "inventory_difference_resolutions", "inventory_depot_regularizations",
        "inventory_movements", "individual_custodies_candidate", "individual_custody_origins_candidate",
        "transfer_finalizations_candidate")
        .stream().map(table -> db.queryForList("SELECT * FROM app." + table + " ORDER BY "
            + (table.equals("individual_custody_origins_candidate") ? "assignment_id" : "id"))).toList();
  }

  @Test
  void emptyCustodyAndLegacyDeliveryNeverInventReceiptOrBalance() {
    db.update("DELETE FROM app.inventory_receipts WHERE assignment_id=?", second);
    var result = service.review(actor, institution, custody);
    assertThat(result.origins()).anySatisfy(origin -> {
      assertThat(origin.assignmentId()).isEqualTo(second);
      assertThat(origin.receipts()).isEmpty();
      assertThat(origin.events()).isEmpty();
    });
    UUID empty = UUID.randomUUID(), otherLot = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_lots VALUES (?,?)", otherLot, institution);
    db.update("INSERT INTO app.individual_custodies_candidate (id,institution_id,lot_id,custodian_id,created_by) VALUES (?,?,?,?,?)",
        empty, institution, otherLot, user, actor);
    assertThat(service.review(actor, institution, empty).origins()).isEmpty();
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_receipts WHERE assignment_id=?", Integer.class, second)).isZero();
  }
}
