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

import com.pai.api.identity.dto.CreateInstitutionAdminRequest;
import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.repository.InstitutionRepository;
import com.pai.api.identity.repository.RoleRepository;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.identity.repository.UserRoleRepository;
import com.pai.api.shared.exceptions.EmailAlreadyExistsException;
import com.pai.api.shared.exceptions.InstitutionNotFoundException;
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
}
