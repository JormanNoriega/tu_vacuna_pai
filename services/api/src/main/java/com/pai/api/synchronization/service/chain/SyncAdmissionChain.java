package com.pai.api.synchronization.service.chain;

import com.pai.api.patients.service.PatientMergeRequestService;
import com.pai.api.shared.application.ProcessedOperationsPort;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * Encapsula la orquestacion y construccion de la cadena de admision
 * (Chain of Responsibility) para el procesamiento de operaciones de sincronizacion.
 */
@Component
public class SyncAdmissionChain {

  private final SyncOperationFilter head;

  @Autowired
  public SyncAdmissionChain(
      ProcessedOperationsPort processedOperations,
      PatientMergeRequestService mergeRequests) {
    this(createDefaultFilters(processedOperations, mergeRequests));
  }

  public SyncAdmissionChain(SyncOperationFilter head) {
    this.head = head;
  }

  /**
   * Pasa el contexto de operacion a traves de la cadena a partir del primer eslabon.
   */
  public SyncOperationResult process(SyncOperationContext context) {
    return head.handle(context);
  }

  private static SyncOperationFilter createDefaultFilters(
      ProcessedOperationsPort processedOperations,
      PatientMergeRequestService mergeRequests) {
    SyncOperationFilter dependencyFilter = new DependencyCheckFilter(processedOperations);
    SyncOperationFilter idempotencyFilter = new IdempotencyCheckFilter(processedOperations);
    SyncOperationFilter commandSupportedFilter = new CommandSupportedFilter();
    SyncOperationFilter permissionFilter = new PermissionCheckFilter();
    SyncOperationFilter domainExecutionFilter = new DomainExecutionFilter(mergeRequests);

    dependencyFilter
        .setNext(idempotencyFilter)
        .setNext(commandSupportedFilter)
        .setNext(permissionFilter)
        .setNext(domainExecutionFilter);

    return dependencyFilter;
  }

  /**
   * Ensambla la cadena predeterminada de 5 eslabones:
   * 1. DependencyCheckFilter
   * 2. IdempotencyCheckFilter
   * 3. CommandSupportedFilter
   * 4. PermissionCheckFilter
   * 5. DomainExecutionFilter
   */
  public static SyncAdmissionChain buildDefault(
      ProcessedOperationsPort processedOperations,
      PatientMergeRequestService mergeRequests) {
    return new SyncAdmissionChain(createDefaultFilters(processedOperations, mergeRequests));
  }
}
