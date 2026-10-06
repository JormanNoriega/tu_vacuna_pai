package com.pai.api.identity.service;

import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.ProvisioningOperationStatus;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.entity.UserRoleEntity;
import com.pai.api.identity.exception.RoleNotFoundException;
import com.pai.api.identity.repository.ProvisioningOperationRepository;
import com.pai.api.identity.repository.RoleRepository;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.identity.repository.UserRoleRepository;
import java.time.Instant;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Fase espejo del aprovisionamiento: crea {@code app.users} + roles y marca la
 * operacion como {@code COMPLETED}, todo en una unica transaccion. Es un bean
 * separado para que el {@code @Transactional} aplique via proxy (la orquestacion
 * remota vive en {@link UserProvisioningService} y no debe retener conexion
 * durante el HTTP a la Edge Function).
 *
 * <p>Si esta transaccion falla, la operacion queda en {@code AUTH_CREATED} y el
 * orquestador compensa (deleteAuthUser) DESPUES del rollback, cuando ninguna
 * fila de {@code app.users} referencia al auth.user y la FK no bloquea el
 * borrado.
 */
@Service
public class UserMirrorWriter {

  private static final Set<ProvisioningOperationStatus> COMPLETABLE_FROM = Set.of(
      ProvisioningOperationStatus.AUTH_CREATED,
      ProvisioningOperationStatus.MIRROR_CREATED,
      ProvisioningOperationStatus.ROLE_ASSIGNED,
      ProvisioningOperationStatus.UNCERTAIN,
      ProvisioningOperationStatus.COMPENSATING,
      ProvisioningOperationStatus.COMPENSATION_FAILED);

  private final UserRepository userRepository;
  private final RoleRepository roleRepository;
  private final UserRoleRepository userRoleRepository;
  private final ProvisioningOperationRepository operationRepository;
  private final IdentityMapper mapper;

  public UserMirrorWriter(
      UserRepository userRepository,
      RoleRepository roleRepository,
      UserRoleRepository userRoleRepository,
      ProvisioningOperationRepository operationRepository,
      IdentityMapper mapper) {
    this.userRepository = userRepository;
    this.roleRepository = roleRepository;
    this.userRoleRepository = userRoleRepository;
    this.operationRepository = operationRepository;
    this.mapper = mapper;
  }

  @Transactional
  public UserResponse writeMirrorAndRoles(ProvisioningOperationEntity operation, String roleCode) {
    RoleEntity role = roleRepository
        .findByCode(roleCode)
        .orElseThrow(
            () -> new RoleNotFoundException("El rol " + roleCode + " no esta configurado."));

    Instant now = Instant.now();
    UserEntity user = new UserEntity(
        operation.getAuthUserId(),
        operation.getEmail(),
        operation.getFullName(),
        operation.getInstitutionId(),
        UserEntity.Status.ACTIVE,
        now,
        now,
        operation.getDocumentType(),
        operation.getDocumentNumber(),
        operation.getPhone(),
        operation.getBirthDate(),
        operation.getGender(),
        operation.getProfessionCode(),
        operation.getProfessionalRegistrationNumber(),
        operation.getProfessionalRegistrationType());
    userRepository.save(user);
    userRoleRepository.save(new UserRoleEntity(operation.getAuthUserId(), role.getId()));

    int rows = operationRepository.markCompleted(operation.getOperationId(), COMPLETABLE_FROM, now);
    if (rows == 0) {
      ProvisioningOperationEntity fresh =
          operationRepository.findById(operation.getOperationId()).orElseThrow();
      if (fresh.getStatus() != ProvisioningOperationStatus.COMPLETED) {
        throw new IllegalStateException("La operacion no pudo marcarse como completada.");
      }
    }

    return mapper.toUserResponse(operation);
  }
}
