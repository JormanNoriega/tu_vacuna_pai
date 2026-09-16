package com.pai.api.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.ProvisioningOperationStatus;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.repository.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class IdentityMapperTest {

  private static final UUID USER_ID = UUID.randomUUID();
  private static final UUID AUTH_USER_ID = UUID.randomUUID();
  private static final UUID INSTITUTION_ID = UUID.randomUUID();
  private static final UUID OPERATION_ID = UUID.randomUUID();

  private UserRepository userRepository;
  private IdentityMapper mapper;

  @BeforeEach
  void setUp() {
    userRepository = mock(UserRepository.class);
    mapper = new IdentityMapper(userRepository);
  }

  private UserEntity user(Instant now) {
    return new UserEntity(
        USER_ID,
        "vac@hosp.a",
        "Vaca Uno",
        INSTITUTION_ID,
        UserEntity.Status.ACTIVE,
        now,
        now,
        "CC",
        "12345678",
        "3001234567",
        null,
        "M",
        "MEDICINE",
        "1234-REG",
        "REGULAR");
  }

  @Test
  void toUserResponse_mapsEntityWithResolvedRoles() {
    when(userRepository.findRolesByUserId(USER_ID))
        .thenReturn(List.of(new RoleEntity(UUID.randomUUID(), "VACCINATOR", "Vacunador")));
    Instant now = Instant.now();

    UserResponse result = mapper.toUserResponse(user(now));

    assertThat(result.id()).isEqualTo(USER_ID);
    assertThat(result.roles()).containsExactly("VACCINATOR");
    assertThat(result.status()).isEqualTo("ACTIVE");
    assertThat(result.documentNumber()).isEqualTo("12345678");
    assertThat(result.professionCode()).isEqualTo("MEDICINE");
  }

  @Test
  void toUserResponse_withExplicitStatusUsesGivenStatus() {
    when(userRepository.findRolesByUserId(USER_ID)).thenReturn(List.of());

    UserResponse result = mapper.toUserResponse(user(Instant.now()), "INACTIVE");

    assertThat(result.status()).isEqualTo("INACTIVE");
  }

  @Test
  void toUserResponse_fromOperationUsesUniqueRoleAndActiveStatus() {
    Instant now = Instant.now();
    ProvisioningOperationEntity op = new ProvisioningOperationEntity(
        OPERATION_ID,
        AUTH_USER_ID,
        "vac@hosp.a",
        "Vaca Uno",
        INSTITUTION_ID,
        "VACCINATOR",
        UUID.randomUUID(),
        ProvisioningOperationStatus.COMPLETED,
        (short) 1,
        null,
        now,
        now);

    UserResponse result = mapper.toUserResponse(op);

    assertThat(result.id()).isEqualTo(AUTH_USER_ID);
    assertThat(result.roles()).containsExactly("VACCINATOR");
    assertThat(result.status()).isEqualTo("ACTIVE");
    assertThat(result.institutionId()).isEqualTo(INSTITUTION_ID);
  }
}
