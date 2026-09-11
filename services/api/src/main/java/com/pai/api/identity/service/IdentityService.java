package com.pai.api.identity.service;

import com.pai.api.identity.dto.MeResponse;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.entity.PermissionEntity;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.repository.InstitutionRepository;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.shared.exceptions.UserNotActiveException;
import com.pai.api.shared.exceptions.UserNotFoundException;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Autoridad de autorizacion de la aplicacion. Resuelve el estado vigente de un
 * usuario autenticado desde la base de datos; nunca confia en claims del JWT ni
 * en valores enviados por el cliente como fuente definitiva.
 *
 * <p>Define los limites transaccionales y el mapeo entidad {@literal ->} DTO.
 * Un controller nunca consulta repositorios ni devuelve entidades JPA.
 */
@Service
public class IdentityService {

    private final UserRepository userRepository;
    private final InstitutionRepository institutionRepository;

    public IdentityService(UserRepository userRepository, InstitutionRepository institutionRepository) {
        this.userRepository = userRepository;
        this.institutionRepository = institutionRepository;
    }

    /**
     * Resuelve el usuario autenticado y sus permisos/roles vigentes.
     *
     * @throws UserNotFoundException si el usuario no existe en app.users
     * @throws UserNotActiveException si el usuario o su institucion no estan activos
     */
    @Transactional(readOnly = true)
    @SuppressWarnings("null")
    public AuthorizedUser resolve(UUID userId) {
        UserEntity user = userRepository
                .findById(userId)
                .orElseThrow(() ->
                        new UserNotFoundException("El usuario no existe o no esta configurado en la aplicacion."));

        if (!user.isActive()) {
            throw new UserNotActiveException("El usuario esta desactivado. No puede acceder a la aplicacion.");
        }

        InstitutionEntity institution = institutionRepository
                .findById(user.getInstitutionId())
                .orElseThrow(
                        () -> new UserNotFoundException("La institucion del usuario no existe o no esta configurada."));

        if (!institution.isActive()) {
            throw new UserNotActiveException("La institucion del usuario esta inactiva.");
        }

        List<String> roles = userRepository.findRolesByUserId(userId).stream()
                .map(RoleEntity::getCode)
                .toList();

        List<String> permissions = userRepository.findPermissionsByUserId(userId).stream()
                .map(PermissionEntity::getCode)
                .toList();

        return new AuthorizedUser(
                user.getId(), user.getEmail(), user.getFullName(), institution, roles, permissions, Instant.now());
    }

    /**
     * Perfil autorizado del usuario para {@code GET /api/v1/me}. El mapeo a DTO
     * ocurre dentro de la transaccion, no despues de que esta se cierra.
     */
    @Transactional(readOnly = true)
    public MeResponse getMe(UUID userId) {
        AuthorizedUser user = resolve(userId);

        MeResponse.InstitutionDto institution = new MeResponse.InstitutionDto(
                user.getInstitution().getId(),
                user.getInstitution().getCode(),
                user.getInstitution().getName());

        return new MeResponse(
                user.getId(),
                user.getEmail(),
                user.getFullName(),
                institution,
                user.getRoles(),
                user.getPermissions(),
                user.getInstitution().getOfflineWindowHours(),
                user.getLastOnlineValidation().toString());
    }
}
