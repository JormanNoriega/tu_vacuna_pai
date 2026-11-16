package com.pai.api.inventory.service;

import java.util.UUID;
import com.pai.api.shared.security.PermissionGuard;
import com.pai.api.identity.service.DataScope;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Composicion experimental, solo pruebas. El vinculo se origina en la
 * recepcion del vacunador, sin autoridad administrativa ni impersonacion.
 * Se debe ejecutar mediante TransactionTemplate; no hay bean ni endpoint.
 */
final class CandidateReceiptOrchestrator {
  private final JdbcTemplate db;
  private final InventoryService inventory;
  private final CandidateCustodyLinkService custody;
  private final CandidateTransferFinalizationService finalization;
  private final PermissionGuard guard;
  private final DataScope scope;
  private final java.util.function.Consumer<ReceiptProof> proofObserver;

  CandidateReceiptOrchestrator(JdbcTemplate db, InventoryService inventory,
      CandidateCustodyLinkService custody, CandidateTransferFinalizationService finalization,
      PermissionGuard guard, DataScope scope) {
    this(db, inventory, custody, finalization, guard, scope, ignored -> {});
  }

  CandidateReceiptOrchestrator(JdbcTemplate db, InventoryService inventory,
      CandidateCustodyLinkService custody, CandidateTransferFinalizationService finalization,
      PermissionGuard guard, DataScope scope, java.util.function.Consumer<ReceiptProof> proofObserver) {
    this.db = db;
    this.inventory = inventory;
    this.custody = custody;
    this.finalization = finalization;
    this.guard = guard;
    this.scope = scope;
    this.proofObserver = java.util.Objects.requireNonNull(proofObserver);
  }

  /** Capacidad no construible por el llamador, válida una vez y solo en la transacción emisora. */
  static final class ReceiptProof {
    private final UUID actor, institution, custody, assignment, receipt;
    private final Object resource;
    private final Thread owner;
    private boolean valid = true;
    private boolean consumed;

    private ReceiptProof(UUID actor, UUID institution, UUID custody, UUID assignment, UUID receipt, Object resource) {
      this.actor = actor;
      this.institution = institution;
      this.custody = custody;
      this.assignment = assignment;
      this.receipt = receipt;
      this.resource = resource;
      this.owner = Thread.currentThread();
    }

    UUID actor() { return actor; }
    UUID institution() { return institution; }
    UUID custody() { return custody; }
    UUID assignment() { return assignment; }
    UUID receipt() { return receipt; }

    void claim(JdbcTemplate db) {
      if (!valid || consumed || Thread.currentThread() != owner
          || !TransactionSynchronizationManager.isActualTransactionActive()
          || resource != TransactionSynchronizationManager.getResource(db.getDataSource()))
        throw new IllegalStateException("Comprobante interno fuera de su transaccion o ya usado.");
      consumed = true;
    }
  }

  private ReceiptProof issueProof(UUID actor, UUID institution, UUID custodyId, UUID assignment, UUID receipt) {
    var source = java.util.Objects.requireNonNull(db.getDataSource());
    Object resource = TransactionSynchronizationManager.getResource(source);
    if (!TransactionSynchronizationManager.isActualTransactionActive()
        || !TransactionSynchronizationManager.isSynchronizationActive() || resource == null)
      throw new IllegalStateException("La recepción requiere una transacción activa.");
    var proof = new ReceiptProof(actor, institution, custodyId, assignment, receipt, resource);
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override public void afterCompletion(int status) { proof.valid = false; }
    });
    return proof;
  }

  @Transactional
  InventoryService.ReceiptResult receive(UUID vaccinator, UUID institution,
      UUID assignment, UUID receipt, int vials, String note, UUID custodyId, UUID finalizationId) {
    // Orden compatible con el vinculador candidato: institución antes de entrega.
    UUID institutionId = scope.resolveInstitutionId(guard.require(vaccinator, "ATTENTION_CREATE"),
        java.util.Objects.requireNonNull(institution, "institution"));
    var institutions = db.query("SELECT id FROM app.institutions WHERE id=? FOR UPDATE",
        (rs, n) -> rs.getObject("id", UUID.class), institutionId);
    if (institutions.isEmpty()) throw new IllegalArgumentException("Institucion no encontrada.");
    var result = inventory.receivePartial(vaccinator, institution, assignment, receipt, vials, note);
    if (vials > 0) {
      var proof = issueProof(vaccinator, institutionId, custodyId, assignment, receipt);
      proofObserver.accept(proof);
      custody.linkFromReceipt(proof);
    }
    if (result.status().equals("RECEIVED")) {
      var evidence = db.queryForMap("SELECT COUNT(*) AS n, "
          + "COALESCE(SUM(CASE WHEN length(trim(difference_note)) > 0 THEN 1 ELSE 0 END),0) AS notes "
          + "FROM app.inventory_receipts WHERE institution_id=? AND assignment_id=?", institution, assignment);
      long events = db.queryForObject("SELECT count(*) FROM app.inventory_custody_events "
          + "WHERE institution_id=? AND assignment_id=?", Long.class, institution, assignment);
      long existing = db.queryForObject("SELECT count(*) FROM app.transfer_finalizations_candidate "
          + "WHERE institution_id=? AND assignment_id=?", Long.class, institution, assignment);
      // Nunca convertimos una diferencia previa o una novedad en cierre automático.
      if (existing > 0 || (((Number) evidence.get("n")).longValue() == 1
          && ((Number) evidence.get("notes")).longValue() == 0 && events == 0)) {
        finalization.finalizeTransfer(vaccinator, institution, assignment, finalizationId, false, "");
      }
    }
    return result;
  }
}
