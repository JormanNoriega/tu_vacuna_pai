package com.pai.api.synchronization.service.chain;

import com.pai.api.attentions.exception.AttentionNotFoundException;
import com.pai.api.attentions.exception.InvalidCatalogSelectionException;
import com.pai.api.attentions.exception.InvalidClinicalStateException;
import com.pai.api.identity.exception.UserNotActiveException;
import com.pai.api.patients.exception.PatientAlreadyExistsException;
import com.pai.api.patients.exception.PatientNotFoundException;
import com.pai.api.patients.service.PatientMergeRequestService;
import com.pai.api.shared.exceptions.PermissionDeniedException;
import com.pai.api.shared.exceptions.ScopeViolationException;
import com.pai.api.synchronization.dto.SyncOperation;
import com.pai.api.synchronization.service.command.SyncCommandHandler;
import java.util.UUID;

/**
 * Eslabon terminal de la cadena de admision:
 * Ejecuta el comando en el servicio de dominio correspondiente y traduce
 * cualquier excepcion de dominio en el motivo estandar de rechazo de sincronizacion.
 */
public class DomainExecutionFilter extends AbstractSyncOperationFilter {

  public static final String REASON_DUPLICATE = "DUPLICATE_BUSINESS_IDENTITY";
  public static final String REASON_DEPENDENCY_NOT_FOUND = "DEPENDENCY_NOT_FOUND";
  public static final String REASON_INVALID_STATE = "INVALID_STATE";
  public static final String REASON_PERMISSION_DENIED = "PERMISSION_DENIED";
  public static final String REASON_USER_NOT_ACTIVE = "USER_NOT_ACTIVE";
  public static final String REASON_INVALID_PAYLOAD = "INVALID_PAYLOAD";

  private final PatientMergeRequestService mergeRequests;

  public DomainExecutionFilter(PatientMergeRequestService mergeRequests) {
    this.mergeRequests = mergeRequests;
  }

  @Override
  protected SyncOperationResult handleCurrent(SyncOperationContext context) {
    SyncOperation operation = context.operation();
    UUID operationId = operation.operationId();
    SyncCommandHandler handler = context.resolvedHandler();

    try {
      handler.apply(context.actorId(), operationId.toString(), operation);
      return SyncOperationResult.accept();
    } catch (PatientAlreadyExistsException ex) {
      mergeRequests.requestReview(ex.getExistingPatientId());
      return SyncOperationResult.reject(operationId, REASON_DUPLICATE, ex.getMessage());
    } catch (PatientNotFoundException | AttentionNotFoundException ex) {
      return SyncOperationResult.reject(operationId, REASON_DEPENDENCY_NOT_FOUND, ex.getMessage());
    } catch (InvalidClinicalStateException | InvalidCatalogSelectionException ex) {
      return SyncOperationResult.reject(operationId, REASON_INVALID_STATE, ex.getMessage());
    } catch (PermissionDeniedException | ScopeViolationException ex) {
      return SyncOperationResult.reject(operationId, REASON_PERMISSION_DENIED, ex.getMessage());
    } catch (UserNotActiveException ex) {
      return SyncOperationResult.reject(operationId, REASON_USER_NOT_ACTIVE, ex.getMessage());
    } catch (IllegalArgumentException ex) {
      return SyncOperationResult.reject(operationId, REASON_INVALID_PAYLOAD, ex.getMessage());
    }
  }
}
