package com.pai.api.identity.service;

import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.UserEntity;
import java.util.List;
import org.springframework.stereotype.Component;

/**
 * Mapeo centralizado entidad {@literal ->} {@link UserResponse} del modulo de
 * identidad (SRP). Es un mapper puro: no consulta la base de datos; los roles
 * se reciben ya resueltos por el servicio (que puede resolverlos en bloque).
 */
@Component
public class IdentityMapper {

  /**
   * Mapea un usuario con su estado persistido y los roles indicados.
   */
  public UserResponse toUserResponse(UserEntity user, List<String> roleCodes) {
    return toUserResponse(user, user.getStatus().name(), roleCodes);
  }

  /**
   * Mapea un usuario con un estado explicito. Se usa cuando el estado se
   * cambio en memoria sin persistirse aun (o via actualizacion scopeada),
   * para que la respuesta refleje el estado recien aplicado.
   */
  public UserResponse toUserResponse(UserEntity user, String status, List<String> roleCodes) {
    return new UserResponse(
        user.getId(),
        user.getEmail(),
        user.getFullName(),
        user.getInstitutionId(),
        roleCodes,
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
