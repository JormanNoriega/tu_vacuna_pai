package com.pai.api.identity.support;

import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.ProvisioningOperationStatus;
import java.time.Instant;
import java.util.UUID;

/**
 * Fixtures de {@link ProvisioningOperationEntity} compartidas por los tests de
 * identidad (DRY). Construye la operacion con los campos base de un vacunador y
 * sin perfil ampliado.
 */
public final class ProvisioningOperations {

  private ProvisioningOperations() {}

  public static ProvisioningOperationEntity operation(
      UUID operationId,
      UUID authUserId,
      UUID actorId,
      UUID institutionId,
      ProvisioningOperationStatus status) {
    Instant now = Instant.now();
    return new ProvisioningOperationEntity(
        operationId,
        authUserId,
        "vac@hosp.a",
        "Vaca Uno",
        institutionId,
        "VACCINATOR",
        actorId,
        status,
        (short) 1,
        null,
        now,
        now,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null);
  }
}
