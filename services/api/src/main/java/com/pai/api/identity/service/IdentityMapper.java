package com.pai.api.identity.service;

import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.repository.UserRepository;
import java.util.List;
import org.springframework.stereotype.Component;

/**
 * Mapeo centralizado entidad {@literal ->} {@link UserResponse} del modulo de
 * identidad. Antes se construia en {@link UserService} (dos variantes),
 * {@link UserProvisioningService#replayResult} y {@link UserMirrorWriter}
 * (DRY/SRP).
 */
@Component
public class IdentityMapper {

  private final UserRepository userRepository;

  public IdentityMapper(UserRepository userRepository) {
    this.userRepository = userRepository;
  }

  /**
   * Mapea un usuario con su estado persistido y sus roles vigentes.
   */
  public UserResponse toUserResponse(UserEntity user) {
    return toUserResponse(user, user.getStatus().name());
  }

  /**
   * Mapea un usuario con un estado explicito. Se usa cuando el estado se
   * cambio en memoria sin persistirse aun (o via actualizacion scopeada),
   * para que la respuesta refleje el estado recien aplicado.
   */
  @SuppressWarnings("null")
  public UserResponse toUserResponse(UserEntity user, String status) {
    return new UserResponse(
        user.getId(),
        user.getEmail(),
        user.getFullName(),
        user.getInstitutionId(),
        userRepository.findRolesByUserId(user.getId()).stream()
            .map(RoleEntity::getCode)
            .toList(),
        status,
        user.getDocumentType(),
        user.getDocumentNumber(),
        user.getPhone(),
        user.getBirthDate(),
        user.getGender(),
        user.getProfessionCode(),
        user.getProfessionalRegistrationNumber(),
        user.getProfessionalRegistrationType());
  }

  /**
   * Mapea una operacion de aprovisionamiento completada. El rol es unico por
   * diseno (los roles de estas operaciones son unicos) y la cuenta se
   * crea siempre como {@code ACTIVE}.
   */
  public UserResponse toUserResponse(ProvisioningOperationEntity op) {
    return new UserResponse(
        op.getAuthUserId(),
        op.getEmail(),
        op.getFullName(),
        op.getInstitutionId(),
        List.of(op.getRole()),
        "ACTIVE",
        op.getDocumentType(),
        op.getDocumentNumber(),
        op.getPhone(),
        op.getBirthDate(),
        op.getGender(),
        op.getProfessionCode(),
        op.getProfessionalRegistrationNumber(),
        op.getProfessionalRegistrationType());
  }
}
