package com.pai.api.identity.service;

import com.pai.api.identity.dto.ProvisioningOperationResponse;
import com.pai.api.identity.dto.ReconciliationResultResponse;
import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.ProvisioningOperationStatus;
import com.pai.api.identity.repository.ProvisioningOperationRepository;
import com.pai.api.identity.service.AuthUserLookupService.OrphanRecord;
import java.util.ArrayList;
import java.util.List;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

/**
 * Reconciliacion de huerfanos de aprovisionamiento: auth.users con
 * {@code operation_id} en su app_metadata y sin espejo en {@code app.users}.
 *
 * <p>La politica aprobada: se completa el espejo (crear {@code app.users} +
 * roles) SOLO cuando la operacion coincide por {@code operation_id} y el email
 * tambien coincide. Un huerfano sin operacion registrada o con email distinto
 * se deja intacto y se reporta; nunca se reclama por email (podria ser el
 * registro de otra persona o de otra operacion).
 *
 * <p>Concurrencia: si dos llamadas reconcilian el mismo huerfano a la vez, la
 * segunda colisiona con el PK de {@code app.users} y devuelve
 * {@code ALREADY_RECONCILED} en vez de un error 500.
 */
@Service
public class ProvisioningReconciliationService {

  private final AuthUserLookupService authUserLookup;
  private final ProvisioningOperationRepository operationRepository;
  private final UserMirrorWriter mirrorWriter;

  public ProvisioningReconciliationService(
      AuthUserLookupService authUserLookup,
      ProvisioningOperationRepository operationRepository,
      UserMirrorWriter mirrorWriter) {
    this.authUserLookup = authUserLookup;
    this.operationRepository = operationRepository;
    this.mirrorWriter = mirrorWriter;
  }

  /**
   * Reconciles todos los huerfanos detectados. Devuelve el resultado de cada
   * uno.
   */
  public List<ReconciliationResultResponse> reconcile() {
    List<OrphanRecord> orphans = authUserLookup.listOrphans();
    List<ReconciliationResultResponse> results = new ArrayList<>(orphans.size());
    for (OrphanRecord orphan : orphans) {
      results.add(reconcileOrphan(orphan));
    }
    return results;
  }

  private ReconciliationResultResponse reconcileOrphan(OrphanRecord orphan) {
    ProvisioningOperationEntity op =
        operationRepository.findById(orphan.operationId()).orElse(null);
    if (op == null) {
      return result(
          orphan,
          ReconciliationResultResponse.Outcome.SKIPPED_WITHOUT_OPERATION,
          "Huerfano sin operacion registrada: no se reclama por email.");
    }
    if (!op.getEmail().equals(orphan.email())) {
      return result(
          orphan,
          ReconciliationResultResponse.Outcome.SKIPPED_EMAIL_MISMATCH,
          "Correlacion rota: el email no coincide con la operacion.");
    }
    if (op.getAuthUserId() != null && !op.getAuthUserId().equals(orphan.authUserId())) {
      return result(
          orphan,
          ReconciliationResultResponse.Outcome.SKIPPED_EMAIL_MISMATCH,
          "El auth.user no coincide con la operacion registrada.");
    }
    if (op.getStatus() == ProvisioningOperationStatus.COMPLETED) {
      return result(
          orphan, ReconciliationResultResponse.Outcome.ALREADY_RECONCILED, "El espejo ya existe.");
    }

    try {
      mirrorWriter.writeMirrorAndRoles(op, op.getRole());
      return result(
          orphan,
          ReconciliationResultResponse.Outcome.RECONCILED,
          "Espejo y roles creados a partir de la operacion registrada.");
    } catch (DataIntegrityViolationException ex) {
      // Concurrencia: otra request o el reconciler ya creo el espejo.
      return result(
          orphan,
          ReconciliationResultResponse.Outcome.ALREADY_RECONCILED,
          "Ya reconciliado por otro proceso.");
    } catch (RuntimeException ex) {
      String detail = ex.getMessage() == null ? ex.getClass().getSimpleName() : ex.getMessage();
      return result(orphan, ReconciliationResultResponse.Outcome.FAILED, detail);
    }
  }

  /**
   * Auditoria: todas las operaciones de aprovisionamiento, mas recientes
   * primero.
   */
  public List<ProvisioningOperationResponse> listOperations() {
    return operationRepository.findAll(Sort.by(Sort.Direction.DESC, "createdAt")).stream()
        .map(ProvisioningOperationResponse::from)
        .toList();
  }

  private ReconciliationResultResponse result(
      OrphanRecord orphan, ReconciliationResultResponse.Outcome outcome, String detail) {
    return new ReconciliationResultResponse(
        orphan.operationId(), orphan.authUserId(), orphan.email(), outcome, detail);
  }
}
