package com.pai.api.inventory.service;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.security.PermissionGuard;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;
import org.springframework.transaction.support.TransactionTemplate;

/** JDBC/H2: ejecuta el DDL aditivo sin la sección específica de RLS PostgreSQL. */
class CustodyWorkflowServiceTest {
  JdbcTemplate db;
  TransactionTemplate tx;
  PermissionGuard guard;
  CustodyWorkflowService service;
  SingleConnectionDataSource source;
  UUID institution=UUID.randomUUID(),actor=UUID.randomUUID(),custodian=UUID.randomUUID(),
      lot=UUID.randomUUID(),vaccine=UUID.randomUUID(),assignment=UUID.randomUUID(),dose=UUID.randomUUID();

  @BeforeEach void setup() throws Exception {
    // H2 2.4 conserva una sesión en ciertos CHECK IN; mantenerla viva en este fixture.
    var ds=new SingleConnectionDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=PostgreSQL;DB_CLOSE_DELAY=-1","sa","",true);
    source=ds;
    db=new JdbcTemplate(ds); tx=new TransactionTemplate(new DataSourceTransactionManager(ds));
    db.execute("CREATE SCHEMA app");
    db.execute("CREATE TABLE app.users(id UUID PRIMARY KEY)");
    db.update("INSERT INTO app.users VALUES (?),(?)",actor,custodian);
    db.execute("CREATE TABLE app.inventory_lots(id UUID PRIMARY KEY,institution_id UUID,vaccine_id UUID,lot_number TEXT)");
    db.execute("CREATE TABLE app.inventory_assignments(id UUID PRIMARY KEY,institution_id UUID,lot_id UUID,"
        +"vaccinator_id UUID,vial_count INT,received_vials INT,resolved_vials INT,status TEXT,"
        +"UNIQUE(institution_id,lot_id,id))");
    db.execute("CREATE TABLE app.inventory_receipts(id UUID PRIMARY KEY,institution_id UUID,assignment_id UUID,"
        +"lot_id UUID,received_by UUID,vials INT,difference_note TEXT)");
    db.execute("CREATE TABLE app.inventory_custody_events(id UUID PRIMARY KEY,institution_id UUID,assignment_id UUID,"
        +"vial_count INT,status TEXT)");
    db.execute("CREATE TABLE app.inventory_difference_resolutions(id UUID PRIMARY KEY,institution_id UUID,"
        +"assignment_id UUID,vial_count INT)");
    db.execute("CREATE TABLE app.attentions(id UUID PRIMARY KEY,institution_id UUID,professional_id UUID,status TEXT)");
    db.execute("CREATE TABLE app.applied_doses(id UUID PRIMARY KEY,attention_id UUID,vaccine_id UUID,lot_number TEXT,"
        +"application_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,status TEXT)");
    String ddl=new ClassPathResource("db/migration/V39__custody_workflow_evidence.sql")
        .getContentAsString(StandardCharsets.UTF_8).split("-- Solo backend")[0]
        .replace("TIMESTAMPTZ","TIMESTAMP WITH TIME ZONE").replace("now()","CURRENT_TIMESTAMP");
    for (String sql:ddl.split(";")) if (!sql.isBlank()) db.execute(sql);
    db.update("INSERT INTO app.inventory_lots VALUES (?,?,?,'L1')",lot,institution,vaccine);
    db.update("INSERT INTO app.inventory_assignments VALUES (?,?,?,?,5,5,0,'RECEIVED')",assignment,institution,lot,custodian);
    db.update("INSERT INTO app.inventory_receipts VALUES (?,?,?,?,?,5,'')",UUID.randomUUID(),institution,assignment,lot,custodian);
    UUID attention=UUID.randomUUID();
    db.update("INSERT INTO app.attentions VALUES (?,?,?,'COMPLETED')",attention,institution,custodian);
    db.update("INSERT INTO app.applied_doses(id,attention_id,vaccine_id,lot_number,status) VALUES (?,?,?,'L1','REGISTERED')",
        dose,attention,vaccine);
    guard=mock(PermissionGuard.class);
    var profile=mock(AuthorizedUser.class); var inst=mock(InstitutionEntity.class);
    when(inst.getId()).thenReturn(institution); when(profile.getInstitution()).thenReturn(inst);
    when(profile.getRoles()).thenReturn(List.of("ADMIN_INSTITUTION"));
    when(profile.getPermissions()).thenReturn(List.of("INVENTORY_READ","INVENTORY_WRITE","ATTENTION_READ","ATTENTION_CREATE"));
    when(guard.require(any(),any())).thenReturn(profile);
    service=new CustodyWorkflowService(db,guard,new DataScope(),true);
  }

  @org.junit.jupiter.api.AfterEach void cleanup() { if (source!=null) source.destroy(); }

  CustodyWorkflowService.Count count(UUID id,int closed,int open) {
    return new CustodyWorkflowService.Count(id,closed,open,0,0,0,"Conteo verificado",null,null);
  }
  CustodyWorkflowService.Workflow read() { return tx.execute(s->service.read(actor,institution,assignment,false)); }

  @Test void countPersistsReplaysAndDoesNotInventMovementOrBalance() {
    UUID id=UUID.randomUUID();
    tx.execute(s->service.recordCount(custodian,institution,assignment,count(id,4,1)));
    tx.execute(s->service.recordCount(custodian,institution,assignment,count(id,4,1)));
    var w=read();
    assertThat(w.counts()).hasSize(1);
    assertThat(w.unaccountedVials()).isZero();
    assertThat(w.custodyState()).isEqualTo("REVIEW_REQUIRED");
    assertThat(w.registeredLinkedDoses()).isZero();
    assertThatThrownBy(()->tx.execute(s->service.recordCount(custodian,institution,assignment,count(id,3,1))))
        .isInstanceOf(IllegalArgumentException.class);
    assertThat(db.queryForObject("SELECT received_vials FROM app.inventory_assignments WHERE id=?",Integer.class,assignment)).isEqualTo(5);
  }

  @Test void discrepanciesAreRecordedNotAutomaticallyResolvedAndCannotBeReviewed() {
    UUID id=UUID.randomUUID();
    tx.execute(s->service.recordCount(custodian,institution,assignment,count(id,2,0)));
    var w=read();
    assertThat(w.unaccountedVials()).isEqualTo(3);
    assertThat(w.custodyState()).isEqualTo("REQUIRES_REVIEW");
    assertThatThrownBy(()->tx.execute(s->service.review(actor,institution,assignment,UUID.randomUUID(),id,w.basis(),"Revisado")))
        .isInstanceOf(IllegalArgumentException.class);
  }

  @Test void finalizationRetainsCustodyPendingReturnsAndRequiresNoTransferDifference() {
    UUID finalId=UUID.randomUUID(), countId=UUID.randomUUID();
    db.update("INSERT INTO app.inventory_custody_events VALUES (?,?,?,1,'RETURN_PENDING')",UUID.randomUUID(),institution,assignment);
    tx.execute(s->service.finalizeTransfer(actor,institution,assignment,finalId,"Traslado revisado"));
    tx.execute(s->service.finalizeTransfer(actor,institution,assignment,finalId,"Traslado revisado"));
    tx.execute(s->service.recordCount(custodian,institution,assignment,count(countId,3,1)));
    var w=read();
    assertThat(w.pendingReturnVials()).isEqualTo(1);
    assertThat(w.finalization().id()).isEqualTo(finalId);
    UUID review=UUID.randomUUID();
    tx.execute(s->service.review(actor,institution,assignment,review,countId,w.basis(),"Conteo y soporte revisados"));
    assertThat(read().custodyState()).isEqualTo("REVIEWED_CUSTODY_CONTINUES");
    // Una confirmación posterior deja obsoleta la revisión anterior.
    db.update("UPDATE app.inventory_custody_events SET status='RETURN_AVAILABLE'");
    assertThat(read().custodyState()).isEqualTo("REVIEW_REQUIRED");
    tx.execute(s->service.review(actor,institution,assignment,review,countId,w.basis(),"Conteo y soporte revisados"));
    assertThat(read().custodyState()).isEqualTo("REVIEW_REQUIRED"); // replay no actualiza evidencia
  }

  @Test void unresolvedTransferCannotFinalizeAndCompleteReceiptCanFinalizeAutomatically() {
    db.update("UPDATE app.inventory_assignments SET received_vials=3,status='PARTIALLY_RECEIVED'");
    assertThatThrownBy(()->tx.execute(s->service.finalizeTransfer(actor,institution,assignment,UUID.randomUUID(),"Revisado")))
        .isInstanceOf(IllegalArgumentException.class);
    tx.executeWithoutResult(s->service.afterReceipt(custodian,institution,assignment));
    assertThat(read().finalization()).isNull();
    db.update("UPDATE app.inventory_assignments SET received_vials=5,status='RECEIVED'");
    tx.executeWithoutResult(s->service.afterReceipt(custodian,institution,assignment));
    tx.executeWithoutResult(s->service.afterReceipt(custodian,institution,assignment));
    assertThat(read().finalization().kind()).isEqualTo("AUTOMATIC");
  }

  @Test void clinicalLinksAreExplicitScopedIdempotentAndCancellationInvalidatesReview() {
    assertThat(read().clinicalDoses()).hasSize(1);
    assertThat(read().registeredLinkedDoses()).isZero();
    UUID link=UUID.randomUUID();
    tx.execute(s->service.linkDose(custodian,institution,assignment,link,dose,"Verifiqué procedencia",true));
    tx.execute(s->service.linkDose(custodian,institution,assignment,link,dose,"Verifiqué procedencia",true));
    assertThat(read().registeredLinkedDoses()).isEqualTo(1);
    assertThatThrownBy(()->tx.execute(s->service.linkDose(actor,institution,assignment,UUID.randomUUID(),dose,"Otro origen",false)))
        .isInstanceOf(IllegalArgumentException.class);
    UUID c=UUID.randomUUID();
    tx.execute(s->service.recordCount(custodian,institution,assignment,count(c,4,1)));
    tx.execute(s->service.finalizeTransfer(actor,institution,assignment,UUID.randomUUID(),"Revisado"));
    var w=read();
    tx.execute(s->service.review(actor,institution,assignment,UUID.randomUUID(),c,w.basis(),"Revisado"));
    db.update("UPDATE app.applied_doses SET status='CANCELLED' WHERE id=?",dose);
    assertThat(read().cancelledLinkedDoses()).isEqualTo(1);
    assertThat(read().custodyState()).isEqualTo("REQUIRES_REVIEW");
    assertThat(db.queryForObject("SELECT COUNT(*) FROM app.inventory_clinical_links",Long.class)).isEqualTo(1);
  }

  @Test void rejectsAnotherCustodianInstitutionVaccineAndLot() {
    assertThatThrownBy(()->service.read(actor,UUID.randomUUID(),assignment,false))
        .isInstanceOf(com.pai.api.shared.exceptions.ScopeViolationException.class);
    assertThatThrownBy(()->tx.execute(s->service.recordCount(actor,institution,assignment,count(UUID.randomUUID(),5,0))))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(()->service.read(custodian,institution,UUID.randomUUID(),true))
        .isInstanceOf(IllegalArgumentException.class);
    db.update("UPDATE app.applied_doses SET lot_number='OTRO'");
    assertThatThrownBy(()->tx.execute(s->service.linkDose(custodian,institution,assignment,UUID.randomUUID(),dose,"Soporte",true)))
        .isInstanceOf(IllegalArgumentException.class);
    db.update("UPDATE app.applied_doses SET lot_number='L1',vaccine_id=?",UUID.randomUUID());
    assertThatThrownBy(()->tx.execute(s->service.linkDose(custodian,institution,assignment,UUID.randomUUID(),dose,"Soporte",true)))
        .isInstanceOf(IllegalArgumentException.class);
    doThrow(new org.springframework.security.access.AccessDeniedException("Sin escritura")).when(guard).require(actor,"INVENTORY_WRITE");
    assertThatThrownBy(()->service.finalizeTransfer(actor,institution,assignment,UUID.randomUUID(),"Soporte"))
        .isInstanceOf(org.springframework.security.access.AccessDeniedException.class);
  }

  @Test void historicalAndIncidentReceiptsRequireAdministrativeFinalization() {
    db.update("UPDATE app.inventory_receipts SET difference_note='Recepción con incidencia'");
    tx.executeWithoutResult(s->service.afterReceipt(custodian,institution,assignment));
    assertThat(read().finalization()).isNull();
    db.update("DELETE FROM app.inventory_receipts");
    tx.executeWithoutResult(s->service.afterReceipt(custodian,institution,assignment));
    assertThat(read().finalization()).isNull();
    tx.execute(s->service.finalizeTransfer(actor,institution,assignment,UUID.randomUUID(),"Revisión de historia sin recepción individual"));
    assertThat(read().finalization().kind()).isEqualTo("ADMIN_REVIEW");
  }

  @Test void newerCountInvalidatesTheBasisEvenWhenQuantitiesAreEqual() {
    UUID first=UUID.randomUUID();
    tx.execute(s->service.recordCount(custodian,institution,assignment,count(first,5,0)));
    tx.execute(s->service.finalizeTransfer(actor,institution,assignment,UUID.randomUUID(),"Traslado revisado"));
    var previous=read();
    tx.execute(s->service.recordCount(custodian,institution,assignment,count(UUID.randomUUID(),5,0)));
    assertThatThrownBy(()->tx.execute(s->service.review(actor,institution,assignment,
        UUID.randomUUID(),first,previous.basis(),"Revisión desactualizada")))
        .isInstanceOf(IllegalArgumentException.class);
    assertThat(read().review()).isNull();
  }

  @Test void disabledWorkflowDoesNotQueryNewTablesAndRollbacksPreserveNoPartialEvidence() {
    var disabled=new CustodyWorkflowService(db,guard,new DataScope(),false);
    assertThat(disabled.read(custodian,institution,assignment,true).recordingEnabled()).isFalse();
    assertThatThrownBy(()->disabled.recordCount(custodian,institution,assignment,count(UUID.randomUUID(),5,0)))
        .isInstanceOf(org.springframework.web.server.ResponseStatusException.class);
    assertThatThrownBy(()->tx.executeWithoutResult(s->{
      service.recordCount(custodian,institution,assignment,count(UUID.randomUUID(),5,0));
      throw new IllegalStateException("rollback");
    })).isInstanceOf(IllegalStateException.class);
    assertThat(read().counts()).isEmpty();
  }
}
