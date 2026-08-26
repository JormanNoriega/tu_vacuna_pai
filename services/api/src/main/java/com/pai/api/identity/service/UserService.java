package com.pai.api.identity.service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pai.api.identity.dto.CreateInstitutionAdminRequest;
import com.pai.api.identity.dto.CreateVaccinatorRequest;
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
import com.pai.api.shared.exceptions.PermissionDeniedException;
import com.pai.api.shared.exceptions.RoleNotFoundException;
import com.pai.api.shared.exceptions.ScopeViolationException;
import com.pai.api.shared.exceptions.UserNotFoundException;

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
    private static final String VACCINATOR_ROLE = "VACCINATOR";
    private static final String SUPER_ADMIN_ROLE = "SUPER_ADMIN";
    private static final String USER_MANAGE_PERMISSION = "USER_MANAGE";
    private static final String INSTITUTION_WRITE_PERMISSION = "INSTITUTION_WRITE";

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
     * Crea un {@code VACCINATOR} en la institucion del actor autenticado.
     *
     * <p>El {@code institutionId} nunca se recibe en el request: se resuelve
     * exclusivamente desde el actor (scope calculado por el servidor). El
     * permiso {@code USER_MANAGE} se revalida aqui como segunda barrera, ademas
     * del {@code @PreAuthorize} del controller, para que una llamada directa al
     * servicio no pueda saltarse la regla (Ajuste 2).
     *
     * @param actorId     id del usuario autenticado (ADMIN_INSTITUTION)
     * @param accessToken access token del actor para invocar las Edge Functions
     */
    @Transactional
    public UserResponse createVaccinator(UUID actorId, String accessToken,
            CreateVaccinatorRequest request) {
        AuthorizedUser actor = identityService.resolve(actorId);
        if (!actor.getPermissions().contains(USER_MANAGE_PERMISSION)) {
            throw new PermissionDeniedException(
                "No tienes permiso para crear vacunadores.");
        }

        String email = request.email().trim().toLowerCase();

        if (userRepository.existsByEmail(email)) {
            throw new EmailAlreadyExistsException(
                "Ya existe un usuario con ese correo.");
        }

        RoleEntity role = roleRepository.findByCode(VACCINATOR_ROLE)
            .orElseThrow(() -> new RoleNotFoundException(
                "El rol VACCINATOR no esta configurado."));

        // 1. Crear la identidad en auth.users (Edge Function con service role).
        // La institucion del actor ya fue validada como activa por resolve().
        UUID authUserId;
        try {
            authUserId = authUserClient.createAuthUser(
                accessToken, email, request.temporaryPassword(), request.fullName().trim());
        } catch (EmailAlreadyExistsException ex) {
            throw new EmailAlreadyExistsException(
                "Ya existe un usuario con ese correo.");
        }

        // 2. Crear el espejo en app.users y el rol. Si falla, compensar sin
        // ocultar la excepcion original: el fallo de compensacion se adjunta
        // como suppressed y la excepcion principal se conserva.
        try {
            Instant now = Instant.now();
            UserEntity user = new UserEntity(
                authUserId,
                email,
                request.fullName().trim(),
                actor.getInstitution().getId(),
                UserEntity.Status.ACTIVE,
                now,
                now);
            userRepository.save(user);
            userRoleRepository.save(new UserRoleEntity(authUserId, role.getId()));
        } catch (RuntimeException ex) {
            log.warn("Compensando: fallo la creacion del espejo app.users para el vacunador {}",
                email, ex);
            try {
                authUserClient.deleteAuthUser(accessToken, authUserId);
            } catch (RuntimeException compensationEx) {
                log.error("No se pudo eliminar el auth.user huerfano {} tras la compensacion",
                    authUserId, compensationEx);
                ex.addSuppressed(compensationEx);
            }
            throw ex;
        }

        return new UserResponse(
            authUserId,
            email,
            request.fullName().trim(),
            actor.getInstitution().getId(),
            List.of(VACCINATOR_ROLE),
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
            .map(this::toResponse)
            .toList();
    }

    /**
     * Activa o desactiva un usuario de la institucion del actor. La
     * autorizacion se revalida aqui (permiso y scope institucional) ademas del
     * {@code @PreAuthorize} del controller.
     *
     * <p>Reglas de defensa: no se puede desactivar la propia cuenta y no se
     * pueden editar usuarios con rol {@code SUPER_ADMIN} salvo que el actor
     * tenga {@code INSTITUTION_WRITE}.
     */
    @Transactional
    public UserResponse updateStatus(UUID actorId, UUID userId, String status) {
        AuthorizedUser actor = identityService.resolve(actorId);
        UserEntity user = findEditableUser(actor, userId);

        UserEntity.Status parsed;
        try {
            parsed = UserEntity.Status.valueOf(status.trim().toUpperCase());
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("Estado invalido. Usa ACTIVE o INACTIVE.");
        }

        if (actorId.equals(userId) && parsed == UserEntity.Status.INACTIVE) {
            throw new IllegalArgumentException("No puedes desactivar tu propia cuenta.");
        }

        user.setStatus(parsed);
        user.setUpdatedAt(Instant.now());
        return toResponse(userRepository.save(user));
    }

    /**
     * Reemplaza los roles de un usuario de la institucion del actor. El rol
     * {@code SUPER_ADMIN} no se asigna por esta via (solo rol institucional:
     * ADMIN_INSTITUTION, VACCINATOR o READ_ONLY).
     */
    @Transactional
    public UserResponse updateRoles(UUID actorId, UUID userId, List<String> roleCodes) {
        AuthorizedUser actor = identityService.resolve(actorId);
        UserEntity user = findEditableUser(actor, userId);

        List<RoleEntity> roles = new ArrayList<>(roleCodes.size());
        for (String code : roleCodes) {
            String normalized = code.trim().toUpperCase();
            if (SUPER_ADMIN_ROLE.equals(normalized)) {
                throw new IllegalArgumentException(
                    "El rol SUPER_ADMIN no se puede asignar desde la aplicacion.");
            }
            RoleEntity role = roleRepository.findByCode(normalized)
                .orElseThrow(() -> new RoleNotFoundException(
                    "El rol " + normalized + " no esta configurado."));
            roles.add(role);
        }

        userRoleRepository.deleteByUserId(userId);
        for (RoleEntity role : roles) {
            userRoleRepository.save(new UserRoleEntity(userId, role.getId()));
        }
        user.setUpdatedAt(Instant.now());
        userRepository.save(user);
        return toResponse(user);
    }

    /**
     * Carga el usuario objetivo y valida el scope del actor. Los usuarios con
     * rol {@code SUPER_ADMIN} solo pueden editarse por actores con
     * {@code INSTITUTION_WRITE}.
     */
    private UserEntity findEditableUser(AuthorizedUser actor, UUID userId) {
        UserEntity user = userRepository.findById(userId)
            .orElseThrow(() -> new UserNotFoundException("El usuario no existe."));

        boolean targetIsSuperAdmin = userRepository.findRolesByUserId(userId).stream()
            .anyMatch(role -> SUPER_ADMIN_ROLE.equals(role.getCode()));
        if (targetIsSuperAdmin && !actor.getPermissions().contains(INSTITUTION_WRITE_PERMISSION)) {
            throw new ScopeViolationException(
                "No tienes permiso para administrar un usuario SUPER_ADMIN.");
        }

        if (!actor.getPermissions().contains(INSTITUTION_WRITE_PERMISSION)
                && !actor.getInstitution().getId().equals(user.getInstitutionId())) {
            throw new ScopeViolationException(
                "No tienes permiso para administrar usuarios de otra institucion.");
        }
        return user;
    }

    private UserResponse toResponse(UserEntity user) {
        return new UserResponse(
            user.getId(),
            user.getEmail(),
            user.getFullName(),
            user.getInstitutionId(),
            userRepository.findRolesByUserId(user.getId()).stream()
                .map(RoleEntity::getCode)
                .toList(),
            user.getStatus().name());
    }
}
