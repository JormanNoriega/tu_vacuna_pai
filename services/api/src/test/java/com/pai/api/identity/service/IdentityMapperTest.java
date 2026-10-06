package com.pai.api.identity.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.ProvisioningOperationStatus;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.support.ProvisioningOperations;
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

  private IdentityMapper mapper;

  @BeforeEach
  void setUp() {
    mapper = new IdentityMapper();
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
    UserResponse result = mapper.toUserResponse(user(Instant.now()), List.of("VACCINATOR"));

    assertThat(result.id()).isEqualTo(USER_ID);
    assertThat(result.roles()).containsExactly("VACCINATOR");
    assertThat(result.status()).isEqualTo("ACTIVE");
    assertThat(result.documentNumber()).isEqualTo("12345678");
    assertThat(result.professionCode()).isEqualTo("MEDICINE");
  }

  @Test
  void toUserResponse_withExplicitStatusUsesGivenStatus() {
    UserResponse result = mapper.toUserResponse(user(Instant.now()), "INACTIVE", List.of());

    assertThat(result.status()).isEqualTo("INACTIVE");
  }

  @Test
  void toUserResponse_fromOperationUsesUniqueRoleAndActiveStatus() {
    ProvisioningOperationEntity op = ProvisioningOperations.operation(
        OPERATION_ID,
        AUTH_USER_ID,
        UUID.randomUUID(),
        INSTITUTION_ID,
        ProvisioningOperationStatus.COMPLETED);

    UserResponse result = mapper.toUserResponse(op);

    assertThat(result.id()).isEqualTo(AUTH_USER_ID);
    assertThat(result.roles()).containsExactly("VACCINATOR");
    assertThat(result.status()).isEqualTo("ACTIVE");
    assertThat(result.institutionId()).isEqualTo(INSTITUTION_ID);
  }
}
