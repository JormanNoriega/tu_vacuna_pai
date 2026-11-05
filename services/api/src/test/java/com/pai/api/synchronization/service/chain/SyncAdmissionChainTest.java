package com.pai.api.synchronization.service.chain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.patients.service.PatientMergeRequestService;
import com.pai.api.shared.application.ProcessedOperationsPort;
import com.pai.api.synchronization.dto.SyncOperation;
import com.pai.api.synchronization.service.command.SyncCommandHandler;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class SyncAdmissionChainTest {

  private ProcessedOperationsPort processedOperations;
  private PatientMergeRequestService mergeRequests;
  private SyncCommandHandler sampleHandler;
  private SyncAdmissionChain chain;

  private final UUID actorId = UUID.randomUUID();
  private final UUID operationId = UUID.randomUUID();
  private final UUID aggregateId = UUID.randomUUID();

  @BeforeEach
  void setUp() {
    processedOperations = mock(ProcessedOperationsPort.class);
    mergeRequests = mock(PatientMergeRequestService.class);
    sampleHandler = mock(SyncCommandHandler.class);
    when(sampleHandler.commandType()).thenReturn("CREATE_SAMPLE");
    when(sampleHandler.permission()).thenReturn("SAMPLE_WRITE");

    chain = SyncAdmissionChain.buildDefault(processedOperations, mergeRequests);
  }

  private AuthorizedUser actor(String... permissions) {
    InstitutionEntity institution = new InstitutionEntity(
        UUID.randomUUID(),
        "INST-1",
        "Hospital Test",
        InstitutionEntity.Status.ACTIVE,
        (short) 72,
        Instant.now(),
        Instant.now());
    return new AuthorizedUser(
        actorId,
        "test@hospital.org",
        "Dr. Test",
        institution,
        List.of("VACCINATOR"),
        List.of(permissions),
        Instant.now());
  }

  @Test
  void short_circuits_on_failed_dependency() {
    UUID failedDep = UUID.randomUUID();
    SyncOperation op = new SyncOperation(
        operationId, "CREATE_SAMPLE", aggregateId, Map.of(), List.of(failedDep));
    SyncOperationContext context = new SyncOperationContext(
        actorId,
        actor("SAMPLE_WRITE"),
        op,
        Map.of(failedDep, false),
        Map.of("CREATE_SAMPLE", sampleHandler));

    SyncOperationResult result = chain.process(context);

    assertThat(result.accepted()).isFalse();
    assertThat(result.rejection().reason()).isEqualTo(DependencyCheckFilter.REASON_DEPENDENCY_FAILED);
  }

  @Test
  void short_circuits_on_idempotent_processed_operation() {
    when(processedOperations.exists(operationId.toString())).thenReturn(true);
    SyncOperation op = new SyncOperation(
        operationId, "CREATE_SAMPLE", aggregateId, Map.of(), List.of());
    SyncOperationContext context = new SyncOperationContext(
        actorId,
        actor("SAMPLE_WRITE"),
        op,
        Map.of(),
        Map.of("CREATE_SAMPLE", sampleHandler));

    SyncOperationResult result = chain.process(context);

    assertThat(result.accepted()).isTrue();
    assertThat(result.rejection()).isNull();
  }

  @Test
  void short_circuits_on_unsupported_command() {
    when(processedOperations.exists(operationId.toString())).thenReturn(false);
    SyncOperation op = new SyncOperation(
        operationId, "UNKNOWN_COMMAND", aggregateId, Map.of(), List.of());
    SyncOperationContext context = new SyncOperationContext(
        actorId,
        actor("SAMPLE_WRITE"),
        op,
        Map.of(),
        Map.of("CREATE_SAMPLE", sampleHandler));

    SyncOperationResult result = chain.process(context);

    assertThat(result.accepted()).isFalse();
    assertThat(result.rejection().reason()).isEqualTo(CommandSupportedFilter.REASON_INVALID_PAYLOAD);
  }

  @Test
  void short_circuits_on_missing_permission() {
    when(processedOperations.exists(operationId.toString())).thenReturn(false);
    SyncOperation op = new SyncOperation(
        operationId, "CREATE_SAMPLE", aggregateId, Map.of(), List.of());
    SyncOperationContext context = new SyncOperationContext(
        actorId,
        actor("OTHER_PERMISSION"),
        op,
        Map.of(),
        Map.of("CREATE_SAMPLE", sampleHandler));

    SyncOperationResult result = chain.process(context);

    assertThat(result.accepted()).isFalse();
    assertThat(result.rejection().reason()).isEqualTo(PermissionCheckFilter.REASON_PERMISSION_DENIED);
  }

  @Test
  void passes_all_filters_and_executes_in_domain() {
    when(processedOperations.exists(operationId.toString())).thenReturn(false);
    SyncOperation op = new SyncOperation(
        operationId, "CREATE_SAMPLE", aggregateId, Map.of(), List.of());
    SyncOperationContext context = new SyncOperationContext(
        actorId,
        actor("SAMPLE_WRITE"),
        op,
        Map.of(),
        Map.of("CREATE_SAMPLE", sampleHandler));

    SyncOperationResult result = chain.process(context);

    assertThat(result.accepted()).isTrue();
    verify(sampleHandler).apply(actorId, operationId.toString(), op);
  }

  @Test
  void allows_extending_chain_with_custom_filter() {
    // Demuestra el cumplimiento de Open/Closed Principle (OCP):
    // Podemos anteponer o intercalar un nuevo eslabon sin modificar el orquestador
    SyncOperationFilter customGuard = new AbstractSyncOperationFilter() {
      @Override
      protected SyncOperationResult handleCurrent(SyncOperationContext ctx) {
        if ("BLOCKED_DEVICE".equals(ctx.actor().getEmail())) {
          return SyncOperationResult.reject(
              ctx.operation().operationId(), "DEVICE_BLOCKED", "Dispositivo bloqueado");
        }
        return proceed(ctx);
      }
    };

    customGuard.setNext(new CommandSupportedFilter());
    SyncAdmissionChain customChain = new SyncAdmissionChain(customGuard);

    InstitutionEntity institution = new InstitutionEntity(
        UUID.randomUUID(), "I1", "H1", InstitutionEntity.Status.ACTIVE, (short) 72, Instant.now(), Instant.now());
    AuthorizedUser blockedActor = new AuthorizedUser(
        actorId, "BLOCKED_DEVICE", "Name", institution, List.of(), List.of(), Instant.now());

    SyncOperation op = new SyncOperation(operationId, "CREATE_SAMPLE", aggregateId, Map.of(), List.of());
    SyncOperationContext context = new SyncOperationContext(
        actorId, blockedActor, op, Map.of(), Map.of("CREATE_SAMPLE", sampleHandler));

    SyncOperationResult result = customChain.process(context);

    assertThat(result.accepted()).isFalse();
    assertThat(result.rejection().reason()).isEqualTo("DEVICE_BLOCKED");
  }
}
