package com.pai.api.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.entity.UserRoleEntity;
import com.pai.api.identity.repository.RoleRepository;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.identity.repository.UserRoleRepository;
import com.pai.api.shared.exceptions.RoleNotFoundException;
import com.pai.api.shared.exceptions.ScopeViolationException;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class UserServiceTest {

    private static final UUID ACTOR_ID = UUID.randomUUID();
    private static final UUID INSTITUTION_ID = UUID.randomUUID();
    private static final UUID ROLE_ID = UUID.randomUUID();

    private UserRepository userRepository;
    private RoleRepository roleRepository;
    private UserRoleRepository userRoleRepository;
    private IdentityService identityService;
    private DataScope dataScope;
    private IdentityMapper mapper;
    private UserService service;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        roleRepository = mock(RoleRepository.class);
        userRoleRepository = mock(UserRoleRepository.class);
        identityService = mock(IdentityService.class);
        dataScope = new DataScope();
        mapper = new IdentityMapper(userRepository);
        service = new UserService(userRepository, roleRepository, userRoleRepository, identityService, dataScope, mapper);
    }

    private static <T> T mock(Class<T> type) {
        return org.mockito.Mockito.mock(type);
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

    private UserEntity vaccinator(UUID id, String email) {
        return new UserEntity(
                id, email, "Vaca", INSTITUTION_ID, UserEntity.Status.ACTIVE, Instant.now(), Instant.now());
    }

    @Test
    void listByInstitution_allowsSuperAdminOnAnyInstitution() {
        UUID other = UUID.randomUUID();
        AuthorizedUser actor = new AuthorizedUser(
                ACTOR_ID,
                "super@admin.test",
                "Super Admin",
                institution(),
                List.of("SUPER_ADMIN"),
                List.of("INSTITUTION_WRITE", "USER_MANAGE"),
                Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);
        when(userRepository.findByInstitutionId(other)).thenReturn(List.of());

        List<UserResponse> result = service.listByInstitution(ACTOR_ID, other, null);

        assertThat(result).isEmpty();
    }

    @Test
    void listByInstitution_blocksAdminInstitutionFromOtherScope() {
        UUID other = UUID.randomUUID();
        AuthorizedUser actor = new AuthorizedUser(
                ACTOR_ID,
                "admin@hosp.a",
                "Admin Hospital A",
                institution(),
                List.of("ADMIN_INSTITUTION"),
                List.of("USER_MANAGE"),
                Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);

        assertThatThrownBy(() -> service.listByInstitution(ACTOR_ID, other, null))
                .isInstanceOf(ScopeViolationException.class);
    }

    @Test
    void listByInstitution_allowsAdminInstitutionInOwnScope() {
        AuthorizedUser actor = new AuthorizedUser(
                ACTOR_ID,
                "admin@hosp.a",
                "Admin Hospital A",
                institution(),
                List.of("ADMIN_INSTITUTION"),
                List.of("USER_MANAGE"),
                Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);
        UserEntity vaccinator = vaccinator(UUID.randomUUID(), "vac@hosp.a");
        when(userRepository.findByInstitutionIdAndRoleCodes(INSTITUTION_ID, Set.of("VACCINATOR", "READ_ONLY")))
                .thenReturn(List.of(vaccinator));
        when(userRepository.findRolesByUserId(vaccinator.getId()))
                .thenReturn(List.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));

        List<UserResponse> result = service.listByInstitution(ACTOR_ID, INSTITUTION_ID, null);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).roles()).containsExactly("VACCINATOR");
    }

    @Test
    void listByInstitution_forcesManagedRolesForInstitutionAdmin() {
        AuthorizedUser actor = new AuthorizedUser(
                ACTOR_ID,
                "admin@hosp.a",
                "Admin Hospital A",
                institution(),
                List.of("ADMIN_INSTITUTION"),
                List.of("USER_MANAGE"),
                Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);
        // El repositorio solo devuelve el vacunador: el admin sembrado en la
        // misma institucion queda fuera del listado de gestion.
        UserEntity vaccinator = vaccinator(UUID.randomUUID(), "vac@hosp.a");
        when(userRepository.findByInstitutionIdAndRoleCodes(INSTITUTION_ID, Set.of("VACCINATOR", "READ_ONLY")))
                .thenReturn(List.of(vaccinator));
        when(userRepository.findRolesByUserId(vaccinator.getId()))
                .thenReturn(List.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));

        List<UserResponse> result = service.listByInstitution(ACTOR_ID, INSTITUTION_ID, null);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).roles()).doesNotContain("ADMIN_INSTITUTION");
    }

    @Test
    void listByInstitution_ignoresClientRolesForInstitutionAdmin() {
        AuthorizedUser actor = new AuthorizedUser(
                ACTOR_ID,
                "admin@hosp.a",
                "Admin Hospital A",
                institution(),
                List.of("ADMIN_INSTITUTION"),
                List.of("USER_MANAGE"),
                Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);
        UserEntity vaccinator = vaccinator(UUID.randomUUID(), "vac@hosp.a");
        when(userRepository.findByInstitutionIdAndRoleCodes(INSTITUTION_ID, Set.of("VACCINATOR", "READ_ONLY")))
                .thenReturn(List.of(vaccinator));
        when(userRepository.findRolesByUserId(vaccinator.getId()))
                .thenReturn(List.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));

        // Aunque el cliente pida ADMIN_INSTITUTION, el filtro efectivo es
        // siempre el conjunto gestionable.
        List<UserResponse> result = service.listByInstitution(ACTOR_ID, INSTITUTION_ID, Set.of("ADMIN_INSTITUTION"));

        assertThat(result).hasSize(1);
        verify(userRepository).findByInstitutionIdAndRoleCodes(INSTITUTION_ID, Set.of("VACCINATOR", "READ_ONLY"));
    }

    @Test
    void listByInstitution_allowsSuperAdminToFilterByRoles() {
        UUID other = UUID.randomUUID();
        AuthorizedUser actor = new AuthorizedUser(
                ACTOR_ID,
                "super@admin.test",
                "Super Admin",
                institution(),
                List.of("SUPER_ADMIN"),
                List.of("INSTITUTION_WRITE", "USER_MANAGE"),
                Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);
        UserEntity admin = new UserEntity(
                UUID.randomUUID(),
                "admin@other",
                "Admin",
                other,
                UserEntity.Status.ACTIVE,
                Instant.now(),
                Instant.now());
        when(userRepository.findByInstitutionIdAndRoleCodes(other, Set.of("ADMIN_INSTITUTION")))
                .thenReturn(List.of(admin));
        when(userRepository.findRolesByUserId(admin.getId()))
                .thenReturn(List.of(new RoleEntity(ROLE_ID, "ADMIN_INSTITUTION", "Admin")));

        List<UserResponse> result = service.listByInstitution(ACTOR_ID, other, Set.of("ADMIN_INSTITUTION"));

        assertThat(result).hasSize(1);
        assertThat(result.get(0).roles()).containsExactly("ADMIN_INSTITUTION");
    }

    // ---------- updateStatus ----------

    private static final UUID TARGET_ID = UUID.randomUUID();

    @Test
    void updateStatus_deactivatesVaccinatorInOwnInstitution() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.findByIdAndInstitutionId(TARGET_ID, INSTITUTION_ID))
                .thenReturn(Optional.of(vaccinator(TARGET_ID, "vac@hosp.a")));
        when(userRepository.findRolesByUserId(TARGET_ID))
                .thenReturn(List.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));
        when(userRepository.updateStatusScoped(
                        eq(TARGET_ID), eq(INSTITUTION_ID), eq(UserEntity.Status.INACTIVE), any(Instant.class)))
                .thenReturn(1);

        UserResponse result = service.updateStatus(ACTOR_ID, TARGET_ID, "INACTIVE");

        assertThat(result.status()).isEqualTo("INACTIVE");
        verify(userRepository)
                .updateStatusScoped(
                        eq(TARGET_ID), eq(INSTITUTION_ID), eq(UserEntity.Status.INACTIVE), any(Instant.class));
        verify(userRepository, never()).save(any(UserEntity.class));
    }

    @Test
    void updateStatus_blocksAdminInstitutionFromOtherInstitution() {
        AuthorizedUser actor = new AuthorizedUser(
                ACTOR_ID,
                "admin@hosp.a",
                "Admin Hospital A",
                institution(),
                List.of("ADMIN_INSTITUTION"),
                List.of("USER_MANAGE"),
                Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);
        // El target de otra institucion nunca se materializa en la query scopeada.
        when(userRepository.findByIdAndInstitutionId(TARGET_ID, INSTITUTION_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.updateStatus(ACTOR_ID, TARGET_ID, "INACTIVE"))
                .isInstanceOf(ScopeViolationException.class);
    }

    @Test
    void updateStatus_rejectsSelfDeactivation() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());

        assertThatThrownBy(() -> service.updateStatus(ACTOR_ID, ACTOR_ID, "INACTIVE"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("propia cuenta");
    }

    @Test
    void updateStatus_blocksSuperAdminTargetForInstitutionAdmin() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.findByIdAndInstitutionId(TARGET_ID, INSTITUTION_ID))
                .thenReturn(Optional.of(vaccinator(TARGET_ID, "vac@hosp.a")));
        when(userRepository.findRolesByUserId(TARGET_ID))
                .thenReturn(List.of(new RoleEntity(ROLE_ID, "SUPER_ADMIN", "Super")));

        assertThatThrownBy(() -> service.updateStatus(ACTOR_ID, TARGET_ID, "INACTIVE"))
                .isInstanceOf(ScopeViolationException.class);
        verify(userRepository, never()).updateStatusScoped(any(), any(), any(), any());
    }

    @Test
    void updateStatus_blocksCoAdminTargetForInstitutionAdmin() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.findByIdAndInstitutionId(TARGET_ID, INSTITUTION_ID))
                .thenReturn(Optional.of(vaccinator(TARGET_ID, "vac@hosp.a")));
        when(userRepository.findRolesByUserId(TARGET_ID))
                .thenReturn(List.of(new RoleEntity(ROLE_ID, "ADMIN_INSTITUTION", "Admin")));

        assertThatThrownBy(() -> service.updateStatus(ACTOR_ID, TARGET_ID, "INACTIVE"))
                .isInstanceOf(ScopeViolationException.class);
    }

    @Test
    void updateStatus_scopeGuaranteesScopedWriteForInstitutionAdmin() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.findByIdAndInstitutionId(TARGET_ID, INSTITUTION_ID))
                .thenReturn(Optional.of(vaccinator(TARGET_ID, "vac@hosp.a")));
        when(userRepository.findRolesByUserId(TARGET_ID))
                .thenReturn(List.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));
        // Red de seguridad: si la UPDATE scopeada no afecta filas (no existe o
        // fuera de alcance), la operacion se aborta.
        when(userRepository.updateStatusScoped(any(), any(), any(), any())).thenReturn(0);

        assertThatThrownBy(() -> service.updateStatus(ACTOR_ID, TARGET_ID, "INACTIVE"))
                .isInstanceOf(ScopeViolationException.class);
    }

    @Test
    void updateStatus_allowsSuperAdminToEditAnyUser() {
        UUID other = UUID.randomUUID();
        AuthorizedUser actor = new AuthorizedUser(
                ACTOR_ID,
                "super@admin.test",
                "Super Admin",
                institution(),
                List.of("SUPER_ADMIN"),
                List.of("INSTITUTION_WRITE", "USER_MANAGE"),
                Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);
        when(userRepository.findById(TARGET_ID))
                .thenReturn(Optional.of(new UserEntity(
                        TARGET_ID, "u@other", "Other", other, UserEntity.Status.ACTIVE, Instant.now(), Instant.now())));
        when(userRepository.findRolesByUserId(TARGET_ID))
                .thenReturn(List.of(new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador")));
        when(userRepository.save(any(UserEntity.class))).thenAnswer(invocation -> invocation.getArgument(0));

        UserResponse result = service.updateStatus(ACTOR_ID, TARGET_ID, "INACTIVE");

        assertThat(result.status()).isEqualTo("INACTIVE");
    }

    @Test
    void updateStatus_rejectsInvalidStatus() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());

        assertThatThrownBy(() -> service.updateStatus(ACTOR_ID, TARGET_ID, "BANANA"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("ACTIVE o INACTIVE");
        verify(userRepository, never()).save(any(UserEntity.class));
    }

    // ---------- updateRoles ----------

    @Test
    @SuppressWarnings("unchecked")
    void updateRoles_replacesRolesOfVaccinator() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(userRepository.findByIdAndInstitutionId(TARGET_ID, INSTITUTION_ID))
                .thenReturn(Optional.of(vaccinator(TARGET_ID, "vac@hosp.a")));
        RoleEntity vaccinatorRole = new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador");
        RoleEntity readOnlyRole = new RoleEntity(UUID.randomUUID(), "READ_ONLY", "Consulta");
        // Primera lectura (guard de target) -> estado previo; la segunda
        // (toResponse) ya refleja el reemplazo.
        when(userRepository.findRolesByUserId(TARGET_ID)).thenReturn(List.of(vaccinatorRole), List.of(readOnlyRole));
        when(roleRepository.findByCode("READ_ONLY")).thenReturn(Optional.of(readOnlyRole));

        UserResponse result = service.updateRoles(ACTOR_ID, TARGET_ID, List.of("READ_ONLY"));

        assertThat(result.roles()).containsExactly("READ_ONLY");
        verify(userRoleRepository).deleteByUserIdScoped(TARGET_ID, INSTITUTION_ID);
        verify(userRepository).touchUpdatedAtScoped(eq(TARGET_ID), eq(INSTITUTION_ID), any(Instant.class));
        ArgumentCaptor<UserRoleEntity> captor = ArgumentCaptor.forClass(UserRoleEntity.class);
        verify(userRoleRepository).save(captor.capture());
        assertThat(captor.getValue().getUserId()).isEqualTo(TARGET_ID);
        assertThat(captor.getValue().getRoleId()).isEqualTo(readOnlyRole.getId());
    }

    @Test
    void updateRoles_rejectsSuperAdminRole() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());

        assertThatThrownBy(() -> service.updateRoles(ACTOR_ID, TARGET_ID, List.of("SUPER_ADMIN")))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("SUPER_ADMIN");
        verify(userRoleRepository, never()).deleteByUserIdScoped(any(), any());
    }

    @Test
    void updateRoles_rejectsUnknownRole() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(roleRepository.findByCode("GHOST")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.updateRoles(ACTOR_ID, TARGET_ID, List.of("GHOST")))
                .isInstanceOf(RoleNotFoundException.class);
        verify(userRoleRepository, never()).deleteByUserIdScoped(any(), any());
    }

    @Test
    void updateRoles_blocksOtherInstitution() {
        AuthorizedUser actor = new AuthorizedUser(
                ACTOR_ID,
                "admin@hosp.a",
                "Admin Hospital A",
                institution(),
                List.of("ADMIN_INSTITUTION"),
                List.of("USER_MANAGE"),
                Instant.now());
        when(identityService.resolve(ACTOR_ID)).thenReturn(actor);
        when(roleRepository.findByCode("READ_ONLY"))
                .thenReturn(Optional.of(new RoleEntity(UUID.randomUUID(), "READ_ONLY", "Consulta")));
        when(userRepository.findByIdAndInstitutionId(TARGET_ID, INSTITUTION_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.updateRoles(ACTOR_ID, TARGET_ID, List.of("READ_ONLY")))
                .isInstanceOf(ScopeViolationException.class);
        verify(userRoleRepository, never()).deleteByUserIdScoped(any(), any());
    }

    @Test
    void updateRoles_blocksCoAdminTargetForInstitutionAdmin() {
        when(identityService.resolve(ACTOR_ID)).thenReturn(adminInstitutionActor());
        when(roleRepository.findByCode("READ_ONLY"))
                .thenReturn(Optional.of(new RoleEntity(UUID.randomUUID(), "READ_ONLY", "Consulta")));
        when(userRepository.findByIdAndInstitutionId(TARGET_ID, INSTITUTION_ID))
                .thenReturn(Optional.of(vaccinator(TARGET_ID, "vac@hosp.a")));
        when(userRepository.findRolesByUserId(TARGET_ID))
                .thenReturn(List.of(new RoleEntity(ROLE_ID, "ADMIN_INSTITUTION", "Admin")));

        assertThatThrownBy(() -> service.updateRoles(ACTOR_ID, TARGET_ID, List.of("READ_ONLY")))
                .isInstanceOf(ScopeViolationException.class);
        verify(userRoleRepository, never()).deleteByUserIdScoped(any(), any());
    }
}
