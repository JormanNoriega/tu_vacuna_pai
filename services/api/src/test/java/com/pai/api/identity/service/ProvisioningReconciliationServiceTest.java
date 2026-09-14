package com.pai.api.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.identity.dto.ProvisioningOperationResponse;
import com.pai.api.identity.dto.ReconciliationResultResponse;
import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.ProvisioningOperationStatus;
import com.pai.api.identity.repository.ProvisioningOperationRepository;
import com.pai.api.identity.service.AuthUserLookupService.OrphanRecord;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Sort;

class ProvisioningReconciliationServiceTest {

  private static final UUID OPERATION_ID = UUID.randomUUID();
  private static final UUID AUTH_USER_ID = UUID.randomUUID();
  private static final UUID INSTITUTION_ID = UUID.randomUUID();

  private AuthUserLookupService authUserLookup;
  private ProvisioningOperationRepository operationRepository;
  private UserMirrorWriter mirrorWriter;
  private ProvisioningReconciliationService service;

  @BeforeEach
  void setUp() {
    authUserLookup = mock(AuthUserLookupService.class);
    operationRepository = mock(ProvisioningOperationRepository.class);
    mirrorWriter = mock(UserMirrorWriter.class);
    service =
        new ProvisioningReconciliationService(authUserLookup, operationRepository, mirrorWriter);
  }

  private OrphanRecord orphan() {
    return new OrphanRecord(OPERATION_ID, AUTH_USER_ID, "vac@hosp.a");
  }

  private ProvisioningOperationEntity operation(ProvisioningOperationStatus status) {
    Instant now = Instant.now();
    return new ProvisioningOperationEntity(
        OPERATION_ID,
        AUTH_USER_ID,
        "vac@hosp.a",
        "Vaca Uno",
        INSTITUTION_ID,
        "VACCINATOR",
        UUID.randomUUID(),
        status,
        (short) 1,
        null,
        now,
        now);
  }

  @Test
  void reconcile_completesMirrorForOrphanWithMatchingOperation() {
    when(authUserLookup.listOrphans()).thenReturn(List.of(orphan()));
    when(operationRepository.findById(OPERATION_ID))
        .thenReturn(Optional.of(operation(ProvisioningOperationStatus.UNCERTAIN)));
    when(mirrorWriter.writeMirrorAndRoles(any(), eq("VACCINATOR"))).thenReturn(null);

    List<ReconciliationResultResponse> results = service.reconcile();

    assertThat(results).hasSize(1);
    assertThat(results.get(0).outcome()).isEqualTo(ReconciliationResultResponse.Outcome.RECONCILED);
    verify(mirrorWriter).writeMirrorAndRoles(any(), eq("VACCINATOR"));
  }

  @Test
  void reconcile_skipsOrphanWithoutOperation() {
    when(authUserLookup.listOrphans()).thenReturn(List.of(orphan()));
    when(operationRepository.findById(OPERATION_ID)).thenReturn(Optional.empty());

    List<ReconciliationResultResponse> results = service.reconcile();

    assertThat(results.get(0).outcome())
        .isEqualTo(ReconciliationResultResponse.Outcome.SKIPPED_WITHOUT_OPERATION);
    verify(mirrorWriter, never()).writeMirrorAndRoles(any(), anyString());
  }

  @Test
  void reconcile_skipsOrphanWithEmailMismatch() {
    when(authUserLookup.listOrphans()).thenReturn(List.of(orphan()));
    // La operacion registro otro correo: correlacion rota, no se reclama.
    when(operationRepository.findById(OPERATION_ID))
        .thenReturn(Optional.of(new ProvisioningOperationEntity(
            OPERATION_ID,
            AUTH_USER_ID,
            "otro@hosp.a",
            "Otro",
            INSTITUTION_ID,
            "VACCINATOR",
            UUID.randomUUID(),
            ProvisioningOperationStatus.UNCERTAIN,
            (short) 1,
            null,
            Instant.now(),
            Instant.now())));

    List<ReconciliationResultResponse> results = service.reconcile();

    assertThat(results.get(0).outcome())
        .isEqualTo(ReconciliationResultResponse.Outcome.SKIPPED_EMAIL_MISMATCH);
    verify(mirrorWriter, never()).writeMirrorAndRoles(any(), anyString());
  }

  @Test
  void reconcile_skipsOrphanWithAuthUserMismatch() {
    when(authUserLookup.listOrphans()).thenReturn(List.of(orphan()));
    // La operacion apunta a otro auth.user: la correlacion no coincide.
    when(operationRepository.findById(OPERATION_ID))
        .thenReturn(Optional.of(new ProvisioningOperationEntity(
            OPERATION_ID,
            UUID.randomUUID(),
            "vac@hosp.a",
            "Vaca Uno",
            INSTITUTION_ID,
            "VACCINATOR",
            UUID.randomUUID(),
            ProvisioningOperationStatus.UNCERTAIN,
            (short) 1,
            null,
            Instant.now(),
            Instant.now())));

    List<ReconciliationResultResponse> results = service.reconcile();

    assertThat(results.get(0).outcome())
        .isEqualTo(ReconciliationResultResponse.Outcome.SKIPPED_EMAIL_MISMATCH);
    verify(mirrorWriter, never()).writeMirrorAndRoles(any(), anyString());
  }

  @Test
  void reconcile_returnsAlreadyReconciledWhenAlreadyCompleted() {
    when(authUserLookup.listOrphans()).thenReturn(List.of(orphan()));
    when(operationRepository.findById(OPERATION_ID))
        .thenReturn(Optional.of(operation(ProvisioningOperationStatus.COMPLETED)));

    List<ReconciliationResultResponse> results = service.reconcile();

    assertThat(results.get(0).outcome())
        .isEqualTo(ReconciliationResultResponse.Outcome.ALREADY_RECONCILED);
    verify(mirrorWriter, never()).writeMirrorAndRoles(any(), anyString());
  }

  @Test
  void reconcile_handlesConcurrentDuplicateWithoutError() {
    when(authUserLookup.listOrphans()).thenReturn(List.of(orphan()));
    when(operationRepository.findById(OPERATION_ID))
        .thenReturn(Optional.of(operation(ProvisioningOperationStatus.UNCERTAIN)));
    when(mirrorWriter.writeMirrorAndRoles(any(), anyString()))
        .thenThrow(new DataIntegrityViolationException("duplicate key"));

    List<ReconciliationResultResponse> results = service.reconcile();

    assertThat(results.get(0).outcome())
        .isEqualTo(ReconciliationResultResponse.Outcome.ALREADY_RECONCILED);
  }

  @Test
  void reconcile_returnsFailedOnOtherError() {
    when(authUserLookup.listOrphans()).thenReturn(List.of(orphan()));
    when(operationRepository.findById(OPERATION_ID))
        .thenReturn(Optional.of(operation(ProvisioningOperationStatus.UNCERTAIN)));
    when(mirrorWriter.writeMirrorAndRoles(any(), anyString()))
        .thenThrow(new RuntimeException("boom"));

    List<ReconciliationResultResponse> results = service.reconcile();

    assertThat(results.get(0).outcome()).isEqualTo(ReconciliationResultResponse.Outcome.FAILED);
  }

  @Test
  void listOperations_mapsEntitiesToResponse() {
    ProvisioningOperationEntity op = operation(ProvisioningOperationStatus.COMPLETED);
    when(operationRepository.findAll(any(Sort.class))).thenReturn(List.of(op));

    List<ProvisioningOperationResponse> responses = service.listOperations();

    assertThat(responses).hasSize(1);
    assertThat(responses.get(0).operationId()).isEqualTo(OPERATION_ID);
    assertThat(responses.get(0).authUserId()).isEqualTo(AUTH_USER_ID);
    assertThat(responses.get(0).status()).isEqualTo(ProvisioningOperationStatus.COMPLETED);
    assertThat(responses.get(0).actorId()).isEqualTo(op.getActorId());
  }
}
