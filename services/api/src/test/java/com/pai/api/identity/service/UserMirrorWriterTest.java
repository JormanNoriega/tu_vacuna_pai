package com.pai.api.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.ProvisioningOperationStatus;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.entity.UserRoleEntity;
import com.pai.api.identity.repository.ProvisioningOperationRepository;
import com.pai.api.identity.repository.RoleRepository;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.identity.repository.UserRoleRepository;
import com.pai.api.shared.exceptions.RoleNotFoundException;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class UserMirrorWriterTest {

    private static final UUID OPERATION_ID = UUID.randomUUID();
    private static final UUID AUTH_USER_ID = UUID.randomUUID();
    private static final UUID INSTITUTION_ID = UUID.randomUUID();
    private static final UUID ROLE_ID = UUID.randomUUID();

    private UserRepository userRepository;
    private RoleRepository roleRepository;
    private UserRoleRepository userRoleRepository;
    private ProvisioningOperationRepository operationRepository;
    private UserMirrorWriter writer;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        roleRepository = mock(RoleRepository.class);
        userRoleRepository = mock(UserRoleRepository.class);
        operationRepository = mock(ProvisioningOperationRepository.class);
        writer = new UserMirrorWriter(
                userRepository, roleRepository, userRoleRepository, operationRepository, new IdentityMapper(userRepository));
        when(userRepository.save(any(UserEntity.class))).thenAnswer(invocation -> invocation.getArgument(0));
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

    private RoleEntity vaccinatorRole() {
        return new RoleEntity(ROLE_ID, "VACCINATOR", "Vacunador");
    }

    @Test
    void writeMirrorAndRoles_createsMirrorRolesAndMarksCompleted() {
        when(roleRepository.findByCode("VACCINATOR")).thenReturn(Optional.of(vaccinatorRole()));
        when(operationRepository.markCompleted(eq(OPERATION_ID), any(), any())).thenReturn(1);

        UserResponse result =
                writer.writeMirrorAndRoles(operation(ProvisioningOperationStatus.AUTH_CREATED), "VACCINATOR");

        assertThat(result.id()).isEqualTo(AUTH_USER_ID);
        assertThat(result.roles()).containsExactly("VACCINATOR");
        assertThat(result.institutionId()).isEqualTo(INSTITUTION_ID);
        assertThat(result.status()).isEqualTo("ACTIVE");

        ArgumentCaptor<UserEntity> userCaptor = ArgumentCaptor.forClass(UserEntity.class);
        verify(userRepository).save(userCaptor.capture());
        assertThat(userCaptor.getValue().getId()).isEqualTo(AUTH_USER_ID);
        assertThat(userCaptor.getValue().getInstitutionId()).isEqualTo(INSTITUTION_ID);
        assertThat(userCaptor.getValue().getStatus()).isEqualTo(UserEntity.Status.ACTIVE);

        ArgumentCaptor<UserRoleEntity> roleCaptor = ArgumentCaptor.forClass(UserRoleEntity.class);
        verify(userRoleRepository).save(roleCaptor.capture());
        assertThat(roleCaptor.getValue().getUserId()).isEqualTo(AUTH_USER_ID);
        assertThat(roleCaptor.getValue().getRoleId()).isEqualTo(ROLE_ID);

        verify(operationRepository).markCompleted(eq(OPERATION_ID), any(), any());
    }

    @Test
    void writeMirrorAndRoles_throwsWhenRoleMissing() {
        when(roleRepository.findByCode("VACCINATOR")).thenReturn(Optional.empty());

        assertThatThrownBy(() ->
                        writer.writeMirrorAndRoles(operation(ProvisioningOperationStatus.AUTH_CREATED), "VACCINATOR"))
                .isInstanceOf(RoleNotFoundException.class);
    }

    @Test
    void writeMirrorAndRoles_acceptsAlreadyCompletedConcurrently() {
        when(roleRepository.findByCode("VACCINATOR")).thenReturn(Optional.of(vaccinatorRole()));
        when(operationRepository.markCompleted(eq(OPERATION_ID), any(), any())).thenReturn(0);
        when(operationRepository.findById(OPERATION_ID))
                .thenReturn(Optional.of(operation(ProvisioningOperationStatus.COMPLETED)));

        UserResponse result =
                writer.writeMirrorAndRoles(operation(ProvisioningOperationStatus.AUTH_CREATED), "VACCINATOR");

        assertThat(result.id()).isEqualTo(AUTH_USER_ID);
    }

    @Test
    void writeMirrorAndRoles_throwsWhenCannotComplete() {
        when(roleRepository.findByCode("VACCINATOR")).thenReturn(Optional.of(vaccinatorRole()));
        when(operationRepository.markCompleted(eq(OPERATION_ID), any(), any())).thenReturn(0);
        when(operationRepository.findById(OPERATION_ID))
                .thenReturn(Optional.of(operation(ProvisioningOperationStatus.PENDING)));

        assertThatThrownBy(() ->
                        writer.writeMirrorAndRoles(operation(ProvisioningOperationStatus.AUTH_CREATED), "VACCINATOR"))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void writeMirrorAndRoles_completesFromReconciliableStates() {
        List<ProvisioningOperationStatus> statuses = List.of(
                ProvisioningOperationStatus.UNCERTAIN,
                ProvisioningOperationStatus.COMPENSATION_FAILED,
                ProvisioningOperationStatus.COMPENSATING);
        when(roleRepository.findByCode("VACCINATOR")).thenReturn(Optional.of(vaccinatorRole()));
        when(operationRepository.markCompleted(eq(OPERATION_ID), any(), any())).thenReturn(1);

        for (ProvisioningOperationStatus status : statuses) {
            UserResponse result = writer.writeMirrorAndRoles(operation(status), "VACCINATOR");
            assertThat(result.id()).isEqualTo(AUTH_USER_ID);
        }
    }
}
