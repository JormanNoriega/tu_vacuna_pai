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

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.pai.api.identity.dto.CreateInstitutionAdminRequest;
import com.pai.api.identity.dto.CreateVaccinatorRequest;
import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.entity.UserRoleEntity;
import com.pai.api.identity.repository.InstitutionRepository;
import com.pai.api.identity.repository.RoleRepository;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.identity.repository.UserRoleRepository;
import com.pai.api.shared.exceptions.EmailAlreadyExistsException;
import com.pai.api.shared.exceptions.InstitutionNotFoundException;
import com.pai.api.shared.exceptions.PermissionDeniedException;
import com.pai.api.shared.exceptions.RoleNotFoundException;
import com.pai.api.shared.exceptions.ScopeViolationException;

class UserServiceTest {

    private static final UUID ACTOR_ID = UUID.randomUUID();
    private static final UUID INSTITUTION_ID = UUID.randomUUID();
    private static final UUID ROLE_ID = UUID.randomUUID();
    private static final UUID AUTH_USER_ID = UUID.randomUUID();
    private static final String ACCESS_TOKEN = "access-token";

    private UserRepository userRepository;
    private InstitutionRepository institutionRepository;
    private RoleRepository roleRepository;
    private UserRoleRepository userRoleRepository;
    private AuthUserProvisioningClient authUserClient;
    private IdentityService identityService;
    private UserService service;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        institutionRepository = mock(InstitutionRepository.class);
        roleRepository = mock(RoleRepository.class);
        userRoleRepository = mock(UserRoleRepository.class);
        authUserClient = mock(AuthUserProvisioningClient.class);
        identityService = mock(IdentityService.class);
        service = new UserService(
            userRepository, institutionRepository, roleRepository,
            userRoleRepository, authUserClient, identityService);
    }

    private CreateInstitutionAdminRequest request() {
        return new CreateInstitutionAdminRequest(
            "ADMIN@HOSP.A", "Admin Hospital A", INSTITUTION_ID, "TempPass123!");
    }

    private InstitutionEntity institution() {
        return new InstitutionEntity(INSTITUTION_ID, "HOSP-A", "Hospital A",
            InstitutionEntity.Status.ACTIVE, (short) 72, Instant.now(), Instant.now());
    }

    private CreateVaccinatorRequest vaccinatorRequest() {
        return new CreateVaccinatorRequest("VAC@HOSP.A", "Vaca Uno", "TempPass123!");
    }

    private AuthorizedUser adminInstitutionActor() {
        return new AuthorizedUser(ACTOR_ID, "admin@hosp.a",
            "Admin Hospital A", institution(), List.of("ADMIN_INSTITUTION"),
            List.of("USER_MANAGE"), Instant.now());
    }

    @Test
    void createInstitutionAdmin_createsAuthUserMirrorAndRole() {
        when(institutionRepository.findById(INSTITUTION_ID))
            .thenReturn(Optional.of(institution()));
        when(userRepository.existsByEmail("admin@hosp.a")).thenReturn(false);
        when(roleRepository.findByCode("ADMIN_INSTITUTION"))
            .thenReturn(Optional.of(new RoleEntity(ROLE_ID, "ADMIN_INSTITUTION", "Admin")));
        when(authUserClient.createAuthUser(ACCESS_TOKEN, "admin@hosp.a",
            "TempPass123!", "Admin Hospital A")).thenReturn(AUTH_USER_ID);

        UserResponse result = service.createInstitutionAdmin(ACTOR_ID, ACCESS_TOKEN, request());

        assertThat(result.id()).isEqualTo(AUTH_USER_ID);
        assertThat(result.email()).isEqualTo("admin@hosp.a");
        assertThat(result.institutionId()).isEqualTo(INSTITUTION_ID);
        assertThat(result.roles()).containsExactly("ADMIN_INSTITUTION");
        verify(userRepository).save(any(UserEntity.class));
        verify(userRoleRepository).save(any());
    }

    @Test
    void createInstitutionAdmin_throwsWhenInstitutionMissing() {
        when(institutionRepository.findById(INSTITUTION_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.createInstitutionAdmin(ACTOR_ID, ACCESS_TOKEN, request()))
            .isInstanceOf(InstitutionNotFoundException.class);
        verify(authUserClient, never()).createAuthUser(anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void createInstitutionAdmin_throwsWhenEmailAlreadyRegistered() {
        when(institutionRepository.findById(INSTITUTION_ID))
            .thenReturn(Optional.of(institution()));
        when(userRepository.existsByEmail("admin@hosp.a")).thenReturn(true);

        assertThatThrownBy(() -> service.createInstitutionAdmin(ACTOR_ID, ACCESS_TOKEN, request()))
            .isInstanceOf(EmailAlreadyExistsException.class);
        verify(authUserClient, never()).createAuthUser(anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void createInstitutionAdmin_throwsWhenRoleMissing() {
        when(institutionRepository.findById(INSTITUTION_ID))
            .thenReturn(Optional.of(institution()));
        when(userRepository.existsByEmail("admin@hosp.a")).thenReturn(false);
        when(roleRepository.findByCode("ADMIN_INSTITUTION")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.createInstitutionAdmin(ACTOR_ID, ACCESS_TOKEN, request()))
            .isInstanceOf(RoleNotFoundException.class);
    }

    @Test
    void createInstitutionAdmin_throwsWhenAuthUserEmailExists() {
        when(institutionRepository.findById(INSTITUTION_ID))
            .thenReturn(Optional.of(institution()));
        when(userRepository.existsByEmail("admin@hosp.a")).thenReturn(false);
        when(roleRepository.findByCode("ADMIN_INSTITUTION"))
            .thenReturn(Optional.of(new RoleEntity(ROLE_ID, "ADMIN_INSTITUTION", "Admin")));
        when(authUserClient.createAuthUser(ACCESS_TOKEN, "admin@hosp.a",
            "TempPass123!", "Admin Hospital A"))
            .thenThrow(new EmailAlreadyExistsException("Ya existe"));

        assertThatThrownBy(() -> service.createInstitutionAdmin(ACTOR_ID, ACCESS_TOKEN, request()))
            .isInstanceOf(EmailAlreadyExistsException.class);
        verify(userRepository, never()).save(any(UserEntity.class));
    }

    @Test
    void createInstitutionAdmin_compensatesWhenAppUserSaveFails() {
        when(institutionRepository.findById(INSTITUTION_ID))
            .thenReturn(Optional.of(institution()));
        when(userRepository.existsByEmail("admin@hosp.a")).thenReturn(false);
        when(roleRepository.findByCode("ADMIN_INSTITUTION"))
            .thenReturn(Optional.of(new RoleEntity(ROLE_ID, "ADMIN_INSTITUTION", "Admin")));
        when(authUserClient.createAuthUser(ACCESS_TOKEN, "admin@hosp.a",
            "TempPass123!", "Admin Hospital A")).thenReturn(AUTH_USER_ID);
        when(userRepository.save(any(UserEntity.class)))
            .thenThrow(new RuntimeException("DB failure"));

        assertThatThrownBy(() -> service.createInstitutionAdmin(ACTOR_ID, ACCESS_TOKEN, request()))
            .isInstanceOf(RuntimeException.class);
        verify(authUserClient).deleteAuthUser(ACCESS_TOKEN, AUTH_USER_ID);
    }

    @Test
    void createInstitutionAdmin_doesNotCompensateOnSuccess() {
        when(institutionRepository.findById(INSTITUTION_ID))
            .thenReturn(Optional.of(institution()));
        when(userRepository.existsByEmail("admin@hosp.a")).thenReturn(false);
        when(roleRepository.findByCode("ADMIN_INSTITUTION"))
            .thenReturn(Optional.of(new RoleEntity(ROLE_ID, "ADMIN_INSTITUTION", "Admin")));
        when(authUserClient.createAuthUser(ACCESS_TOKEN, "admin@hosp.a",
            "TempPass123!", "Admin Hospital A")).thenReturn(AUTH_USER_ID);

        service.createInstitutionAdmin(ACTOR_ID, ACCESS_TOKEN, request());

        verify(authUserClient, never()).deleteAuthUser(eq(ACCESS_TOKEN), any(UUID.class));
    }

    @Test
    void createVaccinator_createsAuthUserMirrorAndRole() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.existsByEmail("vac@hosp.a")).thenReturn(false);
        when(roleRepository.findByCode("VACCINATOR"))
            .thenReturn(Optional.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));
        when(authUserClient.createAuthUser(ACCESS_TOKEN, "vac@hosp.a",
            "TempPass123!", "Vaca Uno")).thenReturn(AUTH_USER_ID);

        UserResponse result = service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest());

        assertThat(result.id()).isEqualTo(AUTH_USER_ID);
        assertThat(result.email()).isEqualTo("vac@hosp.a");
        assertThat(result.institutionId()).isEqualTo(INSTITUTION_ID);
        assertThat(result.roles()).containsExactly("VACCINATOR");
        verify(userRepository).save(any(UserEntity.class));
        verify(userRoleRepository).save(any());
    }

    @Test
    void createVaccinator_blocksActorWithoutUserManagePermission() {
        AuthorizedUser actor = new AuthorizedUser(ACTOR_ID, "admin@hosp.a",
            "Admin Hospital A", institution(), List.of("ADMIN_INSTITUTION"),
            List.of("ATTENTION_CREATE"), Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
            .isInstanceOf(PermissionDeniedException.class);
        verify(authUserClient, never())
            .createAuthUser(anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void createVaccinator_usesActorInstitutionAsScope() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.existsByEmail("vac@hosp.a")).thenReturn(false);
        when(roleRepository.findByCode("VACCINATOR"))
            .thenReturn(Optional.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));
        when(authUserClient.createAuthUser(ACCESS_TOKEN, "vac@hosp.a",
            "TempPass123!", "Vaca Uno")).thenReturn(AUTH_USER_ID);

        service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest());

        ArgumentCaptor<UserEntity> captor = ArgumentCaptor.forClass(UserEntity.class);
        verify(userRepository).save(captor.capture());
        assertThat(captor.getValue().getInstitutionId()).isEqualTo(INSTITUTION_ID);
    }

    @Test
    void createVaccinator_throwsWhenEmailAlreadyRegistered() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.existsByEmail("vac@hosp.a")).thenReturn(true);

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
            .isInstanceOf(EmailAlreadyExistsException.class);
        verify(authUserClient, never())
            .createAuthUser(anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void createVaccinator_throwsWhenRoleMissing() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.existsByEmail("vac@hosp.a")).thenReturn(false);
        when(roleRepository.findByCode("VACCINATOR")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
            .isInstanceOf(RoleNotFoundException.class);
        verify(authUserClient, never())
            .createAuthUser(anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void createVaccinator_throwsWhenAuthUserEmailExists() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.existsByEmail("vac@hosp.a")).thenReturn(false);
        when(roleRepository.findByCode("VACCINATOR"))
            .thenReturn(Optional.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));
        when(authUserClient.createAuthUser(ACCESS_TOKEN, "vac@hosp.a",
            "TempPass123!", "Vaca Uno"))
            .thenThrow(new EmailAlreadyExistsException("Ya existe"));

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
            .isInstanceOf(EmailAlreadyExistsException.class);
        verify(userRepository, never()).save(any(UserEntity.class));
    }

    @Test
    void createVaccinator_compensatesWhenAppUserSaveFails() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.existsByEmail("vac@hosp.a")).thenReturn(false);
        when(roleRepository.findByCode("VACCINATOR"))
            .thenReturn(Optional.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));
        when(authUserClient.createAuthUser(ACCESS_TOKEN, "vac@hosp.a",
            "TempPass123!", "Vaca Uno")).thenReturn(AUTH_USER_ID);
        when(userRepository.save(any(UserEntity.class)))
            .thenThrow(new RuntimeException("DB failure"));

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
            .isInstanceOf(RuntimeException.class);
        verify(authUserClient).deleteAuthUser(ACCESS_TOKEN, AUTH_USER_ID);
    }

    @Test
    void createVaccinator_preservesOriginalExceptionWhenCompensationFails() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.existsByEmail("vac@hosp.a")).thenReturn(false);
        when(roleRepository.findByCode("VACCINATOR"))
            .thenReturn(Optional.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));
        when(authUserClient.createAuthUser(ACCESS_TOKEN, "vac@hosp.a",
            "TempPass123!", "Vaca Uno")).thenReturn(AUTH_USER_ID);
        RuntimeException original = new RuntimeException("DB failure");
        when(userRepository.save(any(UserEntity.class))).thenThrow(original);
        doThrow(new RuntimeException("Compensation failure"))
            .when(authUserClient).deleteAuthUser(ACCESS_TOKEN, AUTH_USER_ID);

        assertThatThrownBy(() -> service.createVaccinator(ACTOR_ID, ACCESS_TOKEN, vaccinatorRequest()))
            .isSameAs(original)
            .satisfies(ex -> assertThat(ex.getSuppressed()).hasSize(1));
        verify(authUserClient).deleteAuthUser(ACCESS_TOKEN, AUTH_USER_ID);
    }

    @Test
    void listByInstitution_allowsSuperAdminOnAnyInstitution() {
        UUID other = UUID.randomUUID();
        AuthorizedUser actor = new AuthorizedUser(ACTOR_ID, "super@admin.test",
            "Super Admin", institution(), List.of("SUPER_ADMIN"),
            List.of("INSTITUTION_WRITE", "USER_MANAGE"), Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);
        when(userRepository.findByInstitutionId(other)).thenReturn(List.of());

        List<UserResponse> result = service.listByInstitution(ACTOR_ID, other);

        assertThat(result).isEmpty();
    }

    @Test
    void listByInstitution_blocksAdminInstitutionFromOtherScope() {
        UUID other = UUID.randomUUID();
        AuthorizedUser actor = new AuthorizedUser(ACTOR_ID, "admin@hosp.a",
            "Admin Hospital A", institution(), List.of("ADMIN_INSTITUTION"),
            List.of("USER_MANAGE"), Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);

        assertThatThrownBy(() -> service.listByInstitution(ACTOR_ID, other))
            .isInstanceOf(ScopeViolationException.class);
    }

    @Test
    void listByInstitution_allowsAdminInstitutionInOwnScope() {
        AuthorizedUser actor = new AuthorizedUser(ACTOR_ID, "admin@hosp.a",
            "Admin Hospital A", institution(), List.of("ADMIN_INSTITUTION"),
            List.of("USER_MANAGE"), Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);
        when(userRepository.findByInstitutionId(INSTITUTION_ID))
            .thenReturn(List.of(new UserEntity(UUID.randomUUID(), "u@hosp.a", "User",
                INSTITUTION_ID, UserEntity.Status.ACTIVE, Instant.now(), Instant.now())));

        List<UserResponse> result = service.listByInstitution(ACTOR_ID, INSTITUTION_ID);

        assertThat(result).hasSize(1);
    }

    // ---------- updateStatus ----------

    private static final UUID TARGET_ID = UUID.randomUUID();

    private UserEntity targetVaccinator() {
        return new UserEntity(TARGET_ID, "vac@hosp.a", "Vaca Uno",
            INSTITUTION_ID, UserEntity.Status.ACTIVE, Instant.now(), Instant.now());
    }

    private void stubTargetInOwnInstitution() {
        when(userRepository.findById(TARGET_ID)).thenReturn(Optional.of(targetVaccinator()));
        when(userRepository.findRolesByUserId(TARGET_ID))
            .thenReturn(List.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));
    }

    @Test
    void updateStatus_deactivatesVaccinatorInOwnInstitution() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        stubTargetInOwnInstitution();
        when(userRepository.save(any(UserEntity.class)))
            .thenAnswer(invocation -> invocation.getArgument(0));

        UserResponse result = service.updateStatus(ACTOR_ID, TARGET_ID, "INACTIVE");

        assertThat(result.status()).isEqualTo("INACTIVE");
        ArgumentCaptor<UserEntity> captor = ArgumentCaptor.forClass(UserEntity.class);
        verify(userRepository).save(captor.capture());
        assertThat(captor.getValue().getStatus()).isEqualTo(UserEntity.Status.INACTIVE);
    }

    @Test
    void updateStatus_blocksAdminInstitutionFromOtherInstitution() {
        UUID other = UUID.randomUUID();
        AuthorizedUser actor = new AuthorizedUser(ACTOR_ID, "admin@hosp.a",
            "Admin Hospital A", institution(), List.of("ADMIN_INSTITUTION"),
            List.of("USER_MANAGE"), Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);
        when(userRepository.findById(TARGET_ID))
            .thenReturn(Optional.of(new UserEntity(TARGET_ID, "u@other", "Other",
                other, UserEntity.Status.ACTIVE, Instant.now(), Instant.now())));
        when(userRepository.findRolesByUserId(TARGET_ID))
            .thenReturn(List.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));

        assertThatThrownBy(() -> service.updateStatus(ACTOR_ID, TARGET_ID, "INACTIVE"))
            .isInstanceOf(ScopeViolationException.class);
    }

    @Test
    void updateStatus_rejectsSelfDeactivation() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.findById(ACTOR_ID))
            .thenReturn(Optional.of(new UserEntity(ACTOR_ID, "admin@hosp.a", "Admin Hospital A",
                INSTITUTION_ID, UserEntity.Status.ACTIVE, Instant.now(), Instant.now())));
        when(userRepository.findRolesByUserId(ACTOR_ID))
            .thenReturn(List.of(new RoleEntity(ROLE_ID, "ADMIN_INSTITUTION", "Admin")));

        assertThatThrownBy(() -> service.updateStatus(ACTOR_ID, ACTOR_ID, "INACTIVE"))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining("propia cuenta");
    }

    @Test
    void updateStatus_blocksSuperAdminTargetForInstitutionAdmin() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.findById(TARGET_ID)).thenReturn(Optional.of(targetVaccinator()));
        when(userRepository.findRolesByUserId(TARGET_ID))
            .thenReturn(List.of(new RoleEntity(ROLE_ID, "SUPER_ADMIN", "Super")));

        assertThatThrownBy(() -> service.updateStatus(ACTOR_ID, TARGET_ID, "INACTIVE"))
            .isInstanceOf(ScopeViolationException.class);
    }

    @Test
    void updateStatus_allowsSuperAdminToEditAnyUser() {
        UUID other = UUID.randomUUID();
        AuthorizedUser actor = new AuthorizedUser(ACTOR_ID, "super@admin.test",
            "Super Admin", institution(), List.of("SUPER_ADMIN"),
            List.of("INSTITUTION_WRITE", "USER_MANAGE"), Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);
        when(userRepository.findById(TARGET_ID))
            .thenReturn(Optional.of(new UserEntity(TARGET_ID, "u@other", "Other",
                other, UserEntity.Status.ACTIVE, Instant.now(), Instant.now())));
        when(userRepository.findRolesByUserId(TARGET_ID))
            .thenReturn(List.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));
        when(userRepository.save(any(UserEntity.class)))
            .thenAnswer(invocation -> invocation.getArgument(0));

        UserResponse result = service.updateStatus(ACTOR_ID, TARGET_ID, "INACTIVE");

        assertThat(result.status()).isEqualTo("INACTIVE");
    }

    @Test
    void updateStatus_rejectsInvalidStatus() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        stubTargetInOwnInstitution();

        assertThatThrownBy(() -> service.updateStatus(ACTOR_ID, TARGET_ID, "BANANA"))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining("ACTIVE o INACTIVE");
        verify(userRepository, never()).save(any(UserEntity.class));
    }

    // ---------- updateRoles ----------

    @Test
    void updateRoles_replacesRolesOfVaccinator() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.findById(TARGET_ID)).thenReturn(Optional.of(targetVaccinator()));
        RoleEntity vaccinatorRole = new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador");
        RoleEntity readOnlyRole = new RoleEntity(UUID.randomUUID(), "READ_ONLY", "Consulta");
        // Primera lectura (guard de SUPER_ADMIN) -> estado previo; la segunda
        // (toResponse) ya refleja el reemplazo.
        when(userRepository.findRolesByUserId(TARGET_ID))
            .thenReturn(List.of(vaccinatorRole), List.of(readOnlyRole));
        when(roleRepository.findByCode("READ_ONLY")).thenReturn(Optional.of(readOnlyRole));

        UserResponse result = service.updateRoles(ACTOR_ID, TARGET_ID, List.of("READ_ONLY"));

        assertThat(result.roles()).containsExactly("READ_ONLY");
        verify(userRoleRepository).deleteByUserId(TARGET_ID);
        ArgumentCaptor<UserRoleEntity> captor =
            ArgumentCaptor.forClass(UserRoleEntity.class);
        verify(userRoleRepository).save(captor.capture());
        assertThat(captor.getValue().getUserId()).isEqualTo(TARGET_ID);
        assertThat(captor.getValue().getRoleId()).isEqualTo(readOnlyRole.getId());
    }

    @Test
    void updateRoles_rejectsSuperAdminRole() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        stubTargetInOwnInstitution();

        assertThatThrownBy(() -> service.updateRoles(ACTOR_ID, TARGET_ID, List.of("SUPER_ADMIN")))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining("SUPER_ADMIN");
        verify(userRoleRepository, never()).deleteByUserId(any());
    }

    @Test
    void updateRoles_rejectsUnknownRole() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        stubTargetInOwnInstitution();
        when(roleRepository.findByCode("GHOST")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.updateRoles(ACTOR_ID, TARGET_ID, List.of("GHOST")))
            .isInstanceOf(RoleNotFoundException.class);
        verify(userRoleRepository, never()).deleteByUserId(any());
    }

    @Test
    void updateRoles_blocksOtherInstitution() {
        UUID other = UUID.randomUUID();
        AuthorizedUser actor = new AuthorizedUser(ACTOR_ID, "admin@hosp.a",
            "Admin Hospital A", institution(), List.of("ADMIN_INSTITUTION"),
            List.of("USER_MANAGE"), Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);
        when(userRepository.findById(TARGET_ID))
            .thenReturn(Optional.of(new UserEntity(TARGET_ID, "u@other", "Other",
                other, UserEntity.Status.ACTIVE, Instant.now(), Instant.now())));
        when(userRepository.findRolesByUserId(TARGET_ID))
            .thenReturn(List.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));

        assertThatThrownBy(() -> service.updateRoles(ACTOR_ID, TARGET_ID, List.of("READ_ONLY")))
            .isInstanceOf(ScopeViolationException.class);
    }
}
