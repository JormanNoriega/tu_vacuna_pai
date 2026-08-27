package com.pai.api.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.entity.PermissionEntity;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.repository.InstitutionRepository;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.shared.exceptions.UserNotActiveException;
import com.pai.api.shared.exceptions.UserNotFoundException;

class IdentityServiceTest {

    private static final UUID USER_ID = UUID.randomUUID();
    private static final UUID INSTITUTION_ID = UUID.randomUUID();

    private UserRepository userRepository;
    private InstitutionRepository institutionRepository;
    private IdentityService service;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        institutionRepository = mock(InstitutionRepository.class);
        service = new IdentityService(userRepository, institutionRepository);
    }

    private UserEntity activeUser() {
        return new UserEntity(USER_ID, "vacunador@test.com", "Ana Vacunadora",
            INSTITUTION_ID, UserEntity.Status.ACTIVE, Instant.now(), Instant.now());
    }

    private UserEntity inactiveUser() {
        return new UserEntity(USER_ID, "vacunador@test.com", "Ana Vacunadora",
            INSTITUTION_ID, UserEntity.Status.INACTIVE, Instant.now(), Instant.now());
    }

    private InstitutionEntity activeInstitution() {
        return new InstitutionEntity(INSTITUTION_ID, "INST-1", "Institucion 1",
            InstitutionEntity.Status.ACTIVE, (short) 72, Instant.now(), Instant.now());
    }

    @Test
    void resolve_returnsProfileWhenUserAndInstitutionAreActive() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(activeUser()));
        when(institutionRepository.findById(INSTITUTION_ID))
            .thenReturn(Optional.of(activeInstitution()));
        when(userRepository.findRolesByUserId(USER_ID))
            .thenReturn(List.of(new RoleEntity(UUID.randomUUID(), "VACCINATOR", "Vacunador")));
        when(userRepository.findPermissionsByUserId(USER_ID))
            .thenReturn(List.of(
                new PermissionEntity(UUID.randomUUID(), "PATIENT_READ", "Leer pacientes"),
                new PermissionEntity(UUID.randomUUID(), "ATTENTION_CREATE", "Crear atenciones")));

        AuthorizedUser result = service.resolve(USER_ID);

        assertThat(result.getId()).isEqualTo(USER_ID);
        assertThat(result.getEmail()).isEqualTo("vacunador@test.com");
        assertThat(result.getRoles()).containsExactly("VACCINATOR");
        assertThat(result.getPermissions()).containsExactlyInAnyOrder(
            "PATIENT_READ", "ATTENTION_CREATE");
        assertThat(result.getInstitution().getOfflineWindowHours()).isEqualTo((short) 72);
        assertThat(result.getLastOnlineValidation()).isNotNull();
    }

    @Test
    void resolve_throwsWhenUserDoesNotExist() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.resolve(USER_ID))
            .isInstanceOf(UserNotFoundException.class);
    }

    @Test
    void resolve_throwsWhenUserIsInactive() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(inactiveUser()));

        assertThatThrownBy(() -> service.resolve(USER_ID))
            .isInstanceOf(UserNotActiveException.class);
    }

    @Test
    void resolve_throwsWhenInstitutionIsInactive() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(activeUser()));
        when(institutionRepository.findById(INSTITUTION_ID))
            .thenReturn(Optional.of(new InstitutionEntity(INSTITUTION_ID, "INST-1",
                "Institucion 1", InstitutionEntity.Status.INACTIVE, (short) 72,
                Instant.now(), Instant.now())));

        assertThatThrownBy(() -> service.resolve(USER_ID))
            .isInstanceOf(UserNotActiveException.class);
    }
}