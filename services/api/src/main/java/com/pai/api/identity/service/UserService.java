package com.pai.api.identity.service;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pai.api.identity.dto.CreateInstitutionAdminRequest;
import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.entity.UserRoleEntity;
import com.pai.api.identity.repository.InstitutionRepository;
import com.pai.api.identity.repository.RoleRepository;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.identity.repository.UserRoleRepository;
import com.pai.api.shared.exceptions.EmailAlreadyExistsException;
import com.pai.api.shared.exceptions.InstitutionNotFoundException;
import com.pai.api.shared.exceptions.RoleNotFoundException;
import com.pai.api.shared.exceptions.ScopeViolationException;

/**
 * Gestion de usuarios administrativos. La creacion de un admin de institucion
 * es la unica escritura de usuarios de esta iteracion (exclusiva de
 * {@code SUPER_ADMIN}).
 *
 * <p>La creacion involucra dos sistemas que no comparten transaccion
 * (Supabase Auth y el esquema {@code app}): se implementa con compensacion. Si
 * falla la creacion del espejo en {@code app.users} o de los roles, se elimina
 * el usuario recien creado en {@code auth.users} para no dejar un usuario
 * huerfano.
 */
@Service
public class UserService {

    private static final Logger log = LoggerFactory.getLogger(UserService.class);
    private static final String ADMIN_INSTITUTION_ROLE = "ADMIN_INSTITUTION";

    private final UserRepository userRepository;
    private final InstitutionRepository institutionRepository;
    private final RoleRepository roleRepository;
    private final UserRoleRepository userRoleRepository;
    private final AuthUserProvisioningClient authUserClient;
    private final IdentityService identityService;

    public UserService(
            UserRepository userRepository,
            InstitutionRepository institutionRepository,
            RoleRepository roleRepository,
            UserRoleRepository userRoleRepository,
            AuthUserProvisioningClient authUserClient,
            IdentityService identityService) {
        this.userRepository = userRepository;
        this.institutionRepository = institutionRepository;
        this.roleRepository = roleRepository;
        this.userRoleRepository = userRoleRepository;
        this.authUserClient = authUserClient;
        this.identityService = identityService;
    }

    /**
     * Crea un {@code ADMIN_INSTITUTION} para una institucion existente.
     *
     * @param actorId     id del usuario autenticado (SUPER_ADMIN)
     * @param accessToken access token del actor para invocar las Edge Functions
     */
    @Transactional
    public UserResponse createInstitutionAdmin(UUID actorId, String accessToken,
            CreateInstitutionAdminRequest request) {
        String email = request.email().trim().toLowerCase();

        InstitutionEntity institution = institutionRepository
            .findById(request.institutionId())
            .orElseThrow(() -> new InstitutionNotFoundException(
                "La institucion no existe."));

        if (userRepository.existsByEmail(email)) {
            throw new EmailAlreadyExistsException(
                "Ya existe un usuario con ese correo.");
        }

        RoleEntity role = roleRepository.findByCode(ADMIN_INSTITUTION_ROLE)
            .orElseThrow(() -> new RoleNotFoundException(
                "El rol ADMIN_INSTITUTION no esta configurado."));

        // 1. Crear la identidad en auth.users (Edge Function con service role).
        UUID authUserId;
        try {
            authUserId = authUserClient.createAuthUser(
                accessToken, email, request.temporaryPassword(), request.fullName().trim());
        } catch (EmailAlreadyExistsException ex) {
            throw new EmailAlreadyExistsException(
                "Ya existe un usuario con ese correo.");
        }

        // 2. Crear el espejo en app.users y el rol. Si falla, compensar.
        try {
            Instant now = Instant.now();
            UserEntity user = new UserEntity(
                authUserId,
                email,
                request.fullName().trim(),
                institution.getId(),
                UserEntity.Status.ACTIVE,
                now,
                now);
            userRepository.save(user);
            userRoleRepository.save(new UserRoleEntity(authUserId, role.getId()));
        } catch (RuntimeException ex) {
            log.warn("Compensando: fallo la creacion del espejo app.users para el usuario {}",
                email, ex);
            try {
                authUserClient.deleteAuthUser(accessToken, authUserId);
            } catch (RuntimeException deleteEx) {
                log.error("No se pudo eliminar el auth.user huerfano {} tras la compensacion",
                    authUserId, deleteEx);
            }
            throw ex;
        }

        return new UserResponse(
            authUserId,
            email,
            request.fullName().trim(),
            institution.getId(),
            List.of(ADMIN_INSTITUTION_ROLE),
            UserEntity.Status.ACTIVE.name());
    }

    /**
     * Lista los usuarios de una institucion. La autorizacion de scope vive en
     * el servicio (no en el controller): el actor se resuelve por su id y se
     * compara contra la institucion solicitada para evitar un IDOR clasico
     * ({@code GET /users?institutionId=OTRA-INSTITUCION}).
     *
     * @param actorId                id del usuario autenticado
     * @param requestedInstitutionId institucion solicitada por el cliente
     */
    @Transactional(readOnly = true)
    public List<UserResponse> listByInstitution(UUID actorId, UUID requestedInstitutionId) {
        AuthorizedUser actor = identityService.resolve(actorId);
        UUID institutionId = requestedInstitutionId;

        if (!actor.getPermissions().contains("INSTITUTION_WRITE")
                && !actor.getInstitution().getId().equals(requestedInstitutionId)) {
            throw new ScopeViolationException(
                "No tienes permiso para consultar usuarios de otra institucion.");
        }

        return userRepository.findByInstitutionId(institutionId).stream()
            .map(user -> new UserResponse(
                user.getId(),
                user.getEmail(),
                user.getFullName(),
                user.getInstitutionId(),
                userRepository.findRolesByUserId(user.getId()).stream()
                    .map(RoleEntity::getCode)
                    .toList(),
                user.getStatus().name()))
            .toList();
    }
}
