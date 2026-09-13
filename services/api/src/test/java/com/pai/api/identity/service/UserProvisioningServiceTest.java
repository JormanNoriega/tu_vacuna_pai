package com.pai.api.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.identity.dto.CreateInstitutionAdminRequest;
import com.pai.api.identity.dto.CreateVaccinatorRequest;
import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.ProvisioningOperationStatus;
import com.pai.api.identity.repository.InstitutionRepository;
import com.pai.api.identity.repository.ProfessionRepository;
import com.pai.api.identity.repository.ProvisioningOperationRepository;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.identity.service.AuthUserLookupService.AuthUserRecord;
import com.pai.api.shared.exceptions.EmailAlreadyExistsException;
import com.pai.api.shared.exceptions.InstitutionNotFoundException;
import com.pai.api.shared.exceptions.PermissionDeniedException;
import com.pai.api.shared.exceptions.UncertainProvisioningException;
import com.pai.api.shared.security.PermissionGuard;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class UserProvisioningServiceTest {

    private static final UUID ACTOR_ID = UUID.randomUUID();
    private static final UUID INSTITUTION_ID = UUID.randomUUID();
    private static final UUID AUTH_USER_ID = UUID.randomUUID();
    private static final UUID OPERATION_ID = UUID.randomUUID();
    private static final String ACCESS_TOKEN = "access-token";

    private IdentityService identityService;
    private PermissionGuard guard;
    private InstitutionRepository institutionRepository;
    private ProfessionRepository professionRepository;
    private AuthUserProvisioningClient authUserClient;
    private ProvisioningOperationRepository operationRepository;
    private AuthUserLookupService authUserLookup;
    private UserMirrorWriter mirrorWriter;
    private UserProvisioningService service;

    @BeforeEach
    void setUp() {
        identityService = mock(IdentityService.class);
        guard = new PermissionGuard(identityService);
        institutionRepository = mock(InstitutionRepository.class);
        professionRepository = mock(ProfessionRepository.class);
        authUserClient = mock(AuthUserProvisioningClient.class);
        operationRepository = mock(ProvisioningOperationRepository.class);
        authUserLookup = mock(AuthUserLookupService.class);
        mirrorWriter = mock(UserMirrorWriter.class);
        service = new UserProvisioningService(
                guard,
                institutionRepository,
                professionRepository,
                authUserClient,
                operationRepository,
                authUserLookup,
                mirrorWriter,
                new IdentityMapper(mock(UserRepository.class)));
        when(professionRepository.existsByCode(anyString())).thenReturn(true);
        when(operationRepository.save(any(ProvisioningOperationEntity.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
        when(operationRepository.adoptAuthUser(eq(OPERATION_ID), any(), eq(AUTH_USER_ID), any()))
                .thenReturn(1);
        when(operationRepository.transition(any(), any(), any(), any(), any(), any()))
                .thenReturn(1);
    }

    private InstitutionEntity institution() {
        return new InstitutionEntity(
                INSTITUTION_ID,
                "HOSP-A",
                "Hospital A",
                InstitutionEntity.Status.ACTIVE,
                (short) 72,
                Instant.now(),
                Instant.now());
    }

    private AuthorizedUser adminInstitutionActor() {
        return new AuthorizedUser(
                ACTOR_ID,
                "admin@hosp.a",
                "Admin Hospital A",
                institution(),
                List.of("ADMIN_INSTITUTION"),
                List.of("USER_MANAGE"),
                Instant.now());
    }

    private AuthorizedUser superAdminActor() {
        return new AuthorizedUser(
                ACTOR_ID,
                "super@admin.test",
                "Super Admin",
                institution(),
                List.of("SUPER_ADMIN"),
                List.of("INSTITUTION_WRITE", "USER_MANAGE"),
                Instant.now());
    }

    private CreateVaccinatorRequest vaccinatorRequest() {
        return new CreateVaccinatorRequest(
                "VAC@HOSP.A",
                "Vaca Uno",
                "TempPass123!",
                OPERATION_ID,
                "CC",
                "12.345.678",
                null,
                null,
                null,
                "ENFERMERO",
                "123456",
                "REGISTRO");
    }

    private CreateInstitutionAdminRequest institutionAdminRequest() {
        return new CreateInstitutionAdminRequest(
                "ADMIN@HOSP.A", "Admin Hospital A", INSTITUTION_ID, "TempPass123!", OPERATION_ID);
    }

    private ProvisioningOperationEntity operation(ProvisioningOperationStatus status, UUID authUserId) {
        Instant now = Instant.now();
        return new ProvisioningOperationEntity(
                OPERATION_ID,
                authUserId,
                "vac@hosp.a",
                "Vaca Uno",
                INSTITUTION_ID,
                "VACCINATOR",
                ACTOR_ID,
                status,
                (short) 1,
                null,
                now,
                now);
    }

    private UserResponse vaccinatorResponse() {
        return new UserResponse(
                AUTH_USER_ID, "vac@hosp.a", "Vaca Uno", INSTITUTION_ID, List.of("VACCINATOR"), "ACTIVE");
    }

    @Test
    void createVaccinator_createsAuthUserMirrorAndRole() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(operationRepository.findById(OPERATION_ID)).thenReturn(Optional.empty());
        when(authUserClient.createAuthUser(
                        eq(ACCESS_TOKEN),
                        eq(OPERATION_ID),
                        eq("vac@hosp.a"),
                        eq("TempPass123!"),
                        eq("Vaca Uno"),
                        any()))
                .thenReturn(AUTH_USER_ID);
        when(mirrorWriter.writeMirrorAndRoles(any(), eq("VACCINATOR"))).thenReturn(vaccinatorResponse());

        UserResponse result = service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest());

        assertThat(result.id()).isEqualTo(AUTH_USER_ID);
        assertThat(result.institutionId()).isEqualTo(INSTITUTION_ID);
        assertThat(result.roles()).containsExactly("VACCINATOR");
        verify(authUserClient)
                .createAuthUser(
                        eq(ACCESS_TOKEN),
                        eq(OPERATION_ID),
                        eq("vac@hosp.a"),
                        eq("TempPass123!"),
                        eq("Vaca Uno"),
                        any());
        verify(operationRepository).adoptAuthUser(eq(OPERATION_ID), any(), eq(AUTH_USER_ID), any());
        verify(mirrorWriter).writeMirrorAndRoles(any(), eq("VACCINATOR"));
    }

    @Test
    void createVaccinator_usesActorInstitutionAsScope() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(operationRepository.findById(OPERATION_ID)).thenReturn(Optional.empty());
        when(authUserClient.createAuthUser(
                        eq(ACCESS_TOKEN),
                        eq(OPERATION_ID),
                        eq("vac@hosp.a"),
                        eq("TempPass123!"),
                        eq("Vaca Uno"),
                        any()))
                .thenReturn(AUTH_USER_ID);
        when(mirrorWriter.writeMirrorAndRoles(any(), eq("VACCINATOR"))).thenReturn(vaccinatorResponse());

        service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest());

        ArgumentCaptor<ProvisioningOperationEntity> captor = ArgumentCaptor.forClass(ProvisioningOperationEntity.class);
        verify(operationRepository).save(captor.capture());
        assertThat(captor.getValue().getInstitutionId()).isEqualTo(INSTITUTION_ID);
        assertThat(captor.getValue().getRole()).isEqualTo("VACCINATOR");
        assertThat(captor.getValue().getActorId()).isEqualTo(ACTOR_ID);
        // Se arranco desde PENDING: adoptAuthUser solo aplica a PENDING/UNCERTAIN.
        verify(operationRepository).adoptAuthUser(eq(OPERATION_ID), any(), eq(AUTH_USER_ID), any());
    }

    @Test
    void createVaccinator_blocksActorWithoutUserManagePermission() {
        AuthorizedUser actor = new AuthorizedUser(
                ACTOR_ID,
                "admin@hosp.a",
                "Admin Hospital A",
                institution(),
                List.of("ADMIN_INSTITUTION"),
                List.of("ATTENTION_CREATE"),
                Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
                .isInstanceOf(PermissionDeniedException.class);
        verify(authUserClient, never())
                .createAuthUser(anyString(), any(), anyString(), anyString(), anyString(), any());
    }

    @Test
    void createVaccinator_emailExistsMarksRejectedWithoutCompensation() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(operationRepository.findById(OPERATION_ID)).thenReturn(Optional.empty());
        when(authUserClient.createAuthUser(
                        eq(ACCESS_TOKEN),
                        eq(OPERATION_ID),
                        eq("vac@hosp.a"),
                        eq("TempPass123!"),
                        eq("Vaca Uno"),
                        any()))
                .thenThrow(new EmailAlreadyExistsException("Ya existe"));

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
                .isInstanceOf(EmailAlreadyExistsException.class);

        // REJECTED (no se creo nada): NUNCA se invoca deleteAuthUser.
        verify(operationRepository)
                .transition(
                        eq(OPERATION_ID),
                        eq(ProvisioningOperationStatus.PENDING),
                        eq(ProvisioningOperationStatus.REJECTED),
                        any(),
                        any(),
                        any());
        verify(authUserClient, never()).deleteAuthUser(anyString(), any());
        verify(mirrorWriter, never()).writeMirrorAndRoles(any(), anyString());
    }

    @Test
    void createVaccinator_timeoutMarksUncertainAndSelfHealsWhenAuthUserExists() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(operationRepository.findById(OPERATION_ID)).thenReturn(Optional.empty());
        when(authUserClient.createAuthUser(
                        eq(ACCESS_TOKEN),
                        eq(OPERATION_ID),
                        eq("vac@hosp.a"),
                        eq("TempPass123!"),
                        eq("Vaca Uno"),
                        any()))
                .thenThrow(new UncertainProvisioningException("timeout"));
        // Supabase si creo el usuario (con metadata) pero la respuesta se perdio.
        when(authUserLookup.findByOperation(OPERATION_ID))
                .thenReturn(Optional.of(new AuthUserRecord(AUTH_USER_ID, "vac@hosp.a")));
        when(mirrorWriter.writeMirrorAndRoles(any(), eq("VACCINATOR"))).thenReturn(vaccinatorResponse());

        UserResponse result = service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest());

        assertThat(result.id()).isEqualTo(AUTH_USER_ID);
        verify(operationRepository)
                .transition(
                        eq(OPERATION_ID),
                        eq(ProvisioningOperationStatus.PENDING),
                        eq(ProvisioningOperationStatus.UNCERTAIN),
                        any(),
                        any(),
                        any());
        verify(operationRepository)
                .transition(
                        eq(OPERATION_ID),
                        eq(ProvisioningOperationStatus.UNCERTAIN),
                        eq(ProvisioningOperationStatus.AUTH_CREATED),
                        eq(AUTH_USER_ID),
                        any(),
                        any());
        verify(mirrorWriter).writeMirrorAndRoles(any(), eq("VACCINATOR"));
    }

    @Test
    void createVaccinator_timeoutMarksUncertainWhenNoEvidence() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(operationRepository.findById(OPERATION_ID)).thenReturn(Optional.empty());
        when(authUserClient.createAuthUser(
                        eq(ACCESS_TOKEN),
                        eq(OPERATION_ID),
                        eq("vac@hosp.a"),
                        eq("TempPass123!"),
                        eq("Vaca Uno"),
                        any()))
                .thenThrow(new UncertainProvisioningException("timeout"));
        when(authUserLookup.findByOperation(OPERATION_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
                .isInstanceOf(UncertainProvisioningException.class);

        verify(operationRepository)
                .transition(
                        eq(OPERATION_ID),
                        eq(ProvisioningOperationStatus.PENDING),
                        eq(ProvisioningOperationStatus.UNCERTAIN),
                        any(),
                        any(),
                        any());
        verify(mirrorWriter, never()).writeMirrorAndRoles(any(), anyString());
    }

    @Test
    void createVaccinator_mirrorFailureCompensatesAfterRollback() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(operationRepository.findById(OPERATION_ID)).thenReturn(Optional.empty());
        when(authUserClient.createAuthUser(
                        eq(ACCESS_TOKEN),
                        eq(OPERATION_ID),
                        eq("vac@hosp.a"),
                        eq("TempPass123!"),
                        eq("Vaca Uno"),
                        any()))
                .thenReturn(AUTH_USER_ID);
        RuntimeException original = new RuntimeException("DB failure");
        when(mirrorWriter.writeMirrorAndRoles(any(), eq("VACCINATOR"))).thenThrow(original);

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
                .isSameAs(original);

        // Compensacion real: COMPENSATING -> deleteAuthUser -> COMPENSATED.
        verify(authUserClient).deleteAuthUser(ACCESS_TOKEN, AUTH_USER_ID);
        verify(operationRepository)
                .transition(
                        eq(OPERATION_ID),
                        eq(ProvisioningOperationStatus.AUTH_CREATED),
                        eq(ProvisioningOperationStatus.COMPENSATING),
                        eq(AUTH_USER_ID),
                        any(),
                        any());
        verify(operationRepository)
                .transition(
                        eq(OPERATION_ID),
                        eq(ProvisioningOperationStatus.COMPENSATING),
                        eq(ProvisioningOperationStatus.COMPENSATED),
                        eq(AUTH_USER_ID),
                        any(),
                        any());
    }

    @Test
    void createVaccinator_compensationFailureMarksCompensationFailed() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(operationRepository.findById(OPERATION_ID)).thenReturn(Optional.empty());
        when(authUserClient.createAuthUser(
                        eq(ACCESS_TOKEN),
                        eq(OPERATION_ID),
                        eq("vac@hosp.a"),
                        eq("TempPass123!"),
                        eq("Vaca Uno"),
                        any()))
                .thenReturn(AUTH_USER_ID);
        RuntimeException original = new RuntimeException("DB failure");
        when(mirrorWriter.writeMirrorAndRoles(any(), eq("VACCINATOR"))).thenThrow(original);
        doThrow(new RuntimeException("Compensation failure"))
                .when(authUserClient)
                .deleteAuthUser(ACCESS_TOKEN, AUTH_USER_ID);

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
                .isSameAs(original)
                .satisfies(ex -> assertThat(ex.getSuppressed()).hasSize(1));

        verify(operationRepository)
                .transition(
                        eq(OPERATION_ID),
                        eq(ProvisioningOperationStatus.COMPENSATING),
                        eq(ProvisioningOperationStatus.COMPENSATION_FAILED),
                        eq(AUTH_USER_ID),
                        any(),
                        any());
    }

    @Test
    void createVaccinator_retryAfterCompletedReplaysWithoutCreating() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(operationRepository.findById(OPERATION_ID))
                .thenReturn(Optional.of(operation(ProvisioningOperationStatus.COMPLETED, AUTH_USER_ID)));

        UserResponse result = service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest());

        assertThat(result.id()).isEqualTo(AUTH_USER_ID);
        assertThat(result.roles()).containsExactly("VACCINATOR");
        verify(authUserClient, never())
                .createAuthUser(anyString(), any(), anyString(), anyString(), anyString(), any());
        verify(mirrorWriter, never()).writeMirrorAndRoles(any(), anyString());
    }

    @Test
    void createVaccinator_retryAfterRejectedThrowsEmailExists() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(operationRepository.findById(OPERATION_ID))
                .thenReturn(Optional.of(operation(ProvisioningOperationStatus.REJECTED, null)));

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
                .isInstanceOf(EmailAlreadyExistsException.class);
        verify(authUserClient, never())
                .createAuthUser(anyString(), any(), anyString(), anyString(), anyString(), any());
    }

    @Test
    void createVaccinator_retryAfterUncertainResolvesAndCompletes() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(operationRepository.findById(OPERATION_ID))
                .thenReturn(Optional.of(operation(ProvisioningOperationStatus.UNCERTAIN, null)));
        when(authUserLookup.findByOperation(OPERATION_ID))
                .thenReturn(Optional.of(new AuthUserRecord(AUTH_USER_ID, "vac@hosp.a")));
        when(mirrorWriter.writeMirrorAndRoles(any(), eq("VACCINATOR"))).thenReturn(vaccinatorResponse());

        UserResponse result = service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest());

        assertThat(result.id()).isEqualTo(AUTH_USER_ID);
        // No se recrea el auth.user: se resuelve por metadata.
        verify(authUserClient, never())
                .createAuthUser(anyString(), any(), anyString(), anyString(), anyString(), any());
        verify(operationRepository)
                .transition(
                        eq(OPERATION_ID),
                        eq(ProvisioningOperationStatus.UNCERTAIN),
                        eq(ProvisioningOperationStatus.AUTH_CREATED),
                        eq(AUTH_USER_ID),
                        any(),
                        any());
        verify(mirrorWriter).writeMirrorAndRoles(any(), eq("VACCINATOR"));
    }

    @Test
    void createVaccinator_operationEmailMismatchRejected() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        ProvisioningOperationEntity other = new ProvisioningOperationEntity(
                OPERATION_ID,
                null,
                "otro@hosp.a",
                "Otro",
                INSTITUTION_ID,
                "VACCINATOR",
                ACTOR_ID,
                ProvisioningOperationStatus.PENDING,
                (short) 1,
                null,
                Instant.now(),
                Instant.now());
        when(operationRepository.findById(OPERATION_ID)).thenReturn(Optional.of(other));

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
                .isInstanceOf(IllegalArgumentException.class);
        verify(authUserClient, never())
                .createAuthUser(anyString(), any(), anyString(), anyString(), anyString(), any());
    }

    @Test
    void createVaccinator_retryAfterCompensatedRestartsFresh() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(operationRepository.findById(OPERATION_ID))
                .thenReturn(Optional.of(operation(ProvisioningOperationStatus.COMPENSATED, AUTH_USER_ID)));
        when(authUserClient.createAuthUser(
                        eq(ACCESS_TOKEN),
                        eq(OPERATION_ID),
                        eq("vac@hosp.a"),
                        eq("TempPass123!"),
                        eq("Vaca Uno"),
                        any()))
                .thenReturn(AUTH_USER_ID);
        when(mirrorWriter.writeMirrorAndRoles(any(), eq("VACCINATOR"))).thenReturn(vaccinatorResponse());

        service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest());

        // Se reabrio la operacion: el auth.user se crea de nuevo y se adopta
        // desde PENDING (createAuthUser solo ocurre si el estado se reseteo).
        verify(operationRepository).save(any(ProvisioningOperationEntity.class));
        verify(authUserClient)
                .createAuthUser(
                        eq(ACCESS_TOKEN),
                        eq(OPERATION_ID),
                        eq("vac@hosp.a"),
                        eq("TempPass123!"),
                        eq("Vaca Uno"),
                        any());
        verify(operationRepository).adoptAuthUser(eq(OPERATION_ID), any(), eq(AUTH_USER_ID), any());
        verify(mirrorWriter).writeMirrorAndRoles(any(), eq("VACCINATOR"));
    }

    @Test
    void createInstitutionAdmin_createsAuthUserMirrorAndRole() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(superAdminActor());
        when(institutionRepository.findById(INSTITUTION_ID)).thenReturn(Optional.of(institution()));
        when(operationRepository.findById(OPERATION_ID)).thenReturn(Optional.empty());
        when(authUserClient.createAuthUser(
                        eq(ACCESS_TOKEN),
                        eq(OPERATION_ID),
                        eq("admin@hosp.a"),
                        eq("TempPass123!"),
                        eq("Admin Hospital A"),
                        any()))
                .thenReturn(AUTH_USER_ID);
        when(mirrorWriter.writeMirrorAndRoles(any(), eq("ADMIN_INSTITUTION")))
                .thenReturn(new UserResponse(
                        AUTH_USER_ID,
                        "admin@hosp.a",
                        "Admin Hospital A",
                        INSTITUTION_ID,
                        List.of("ADMIN_INSTITUTION"),
                        "ACTIVE"));

        UserResponse result = service.createInstitutionAdmin(ACTOR_ID, ACCESS_TOKEN, institutionAdminRequest());

        assertThat(result.id()).isEqualTo(AUTH_USER_ID);
        assertThat(result.roles()).containsExactly("ADMIN_INSTITUTION");
        verify(mirrorWriter).writeMirrorAndRoles(any(), eq("ADMIN_INSTITUTION"));
    }

    @Test
    void createInstitutionAdmin_blocksActorWithoutInstitutionWrite() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());

        assertThatThrownBy(() -> service.createInstitutionAdmin(ACTOR_ID, ACCESS_TOKEN, institutionAdminRequest()))
                .isInstanceOf(PermissionDeniedException.class);
        verify(authUserClient, never())
                .createAuthUser(anyString(), any(), anyString(), anyString(), anyString(), any());
    }

    @Test
    void createInstitutionAdmin_throwsWhenInstitutionMissing() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(superAdminActor());
        when(institutionRepository.findById(INSTITUTION_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.createInstitutionAdmin(ACTOR_ID, ACCESS_TOKEN, institutionAdminRequest()))
                .isInstanceOf(InstitutionNotFoundException.class);
        verify(authUserClient, never())
                .createAuthUser(anyString(), any(), anyString(), anyString(), anyString(), any());
    }

    @Test
    void createVaccinator_normalizesDocumentBeforePersisting() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(operationRepository.findById(OPERATION_ID)).thenReturn(Optional.empty());
        when(authUserClient.createAuthUser(
                        eq(ACCESS_TOKEN),
                        eq(OPERATION_ID),
                        eq("vac@hosp.a"),
                        eq("TempPass123!"),
                        eq("Vaca Uno"),
                        any()))
                .thenReturn(AUTH_USER_ID);
        when(mirrorWriter.writeMirrorAndRoles(any(), eq("VACCINATOR"))).thenReturn(vaccinatorResponse());

        service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest());

        ArgumentCaptor<ProvisioningOperationEntity> captor = ArgumentCaptor.forClass(ProvisioningOperationEntity.class);
        verify(operationRepository).save(captor.capture());
        assertThat(captor.getValue().getDocumentType()).isEqualTo("CC");
        // "12.345.678" -> forma canonica "12345678".
        assertThat(captor.getValue().getDocumentNumber()).isEqualTo("12345678");
        assertThat(captor.getValue().getProfessionCode()).isEqualTo("ENFERMERO");
        assertThat(captor.getValue().getProfessionalRegistrationNumber()).isEqualTo("123456");
    }

    @Test
    void createVaccinator_rejectsInvalidDocumentForType() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        CreateVaccinatorRequest request = new CreateVaccinatorRequest(
                "VAC@HOSP.A",
                "Vaca Uno",
                "TempPass123!",
                OPERATION_ID,
                "CC",
                "12.345.678-XYZ",
                null,
                null,
                null,
                "ENFERMERO",
                null,
                null);

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, request))
                .isInstanceOf(IllegalArgumentException.class);
        verify(authUserClient, never())
                .createAuthUser(anyString(), any(), anyString(), anyString(), anyString(), any());
        verify(mirrorWriter, never()).writeMirrorAndRoles(any(), anyString());
    }

    @Test
    void createVaccinator_rejectsUnknownProfession() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(professionRepository.existsByCode("MEDICO")).thenReturn(false);
        CreateVaccinatorRequest request = new CreateVaccinatorRequest(
                "VAC@HOSP.A",
                "Vaca Uno",
                "TempPass123!",
                OPERATION_ID,
                "CC",
                "12345678",
                null,
                null,
                null,
                "MEDICO",
                null,
                null);

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, request))
                .isInstanceOf(IllegalArgumentException.class);
        verify(authUserClient, never())
                .createAuthUser(anyString(), any(), anyString(), anyString(), anyString(), any());
        verify(mirrorWriter, never()).writeMirrorAndRoles(any(), anyString());
    }

    @Test
    void createVaccinator_operationDocumentMismatchRejected() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        ProvisioningOperationEntity other = new ProvisioningOperationEntity(
                OPERATION_ID,
                null,
                "vac@hosp.a",
                "Vaca Uno",
                INSTITUTION_ID,
                "VACCINATOR",
                ACTOR_ID,
                ProvisioningOperationStatus.PENDING,
                (short) 1,
                null,
                Instant.now(),
                Instant.now(),
                "CC",
                "99999999",
                null,
                null,
                null,
                "ENFERMERO",
                null,
                null);
        when(operationRepository.findById(OPERATION_ID)).thenReturn(Optional.of(other));

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
                .isInstanceOf(IllegalArgumentException.class);
        verify(authUserClient, never())
                .createAuthUser(anyString(), any(), anyString(), anyString(), anyString(), any());
    }
}
