package com.pai.api.identity.service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
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
 *
 * <p>El alcance institucional se deriva del actor via {@link DataScope}
 * (equivalente a RLS en la capa de datos): las lecturas y escrituras de
 * usuarios usan consultas scopeadas por {@code institution_id}, de modo que un
 * recurso de otra institucion nunca se materializa ni se modifica.
 */
@Service
public class UserService {

    private static final Logger log = LoggerFactory.getLogger(UserService.class);
    private static final String ADMIN_INSTITUTION_ROLE = "ADMIN_INSTITUTION";
    private static final String VACCINATOR_ROLE = "VACCINATOR";
    private static final String READ_ONLY_ROLE = "READ_ONLY";
    private static final String SUPER_ADMIN_ROLE = "SUPER_ADMIN";
    private static final String USER_MANAGE_PERMISSION = "USER_MANAGE";
    private static final String INSTITUTION_WRITE_PERMISSION = "INSTITUTION_WRITE";

    /**
     * Roles que un ADMIN_INSTITUTION administra. El listado de gestion se
     * fuerza a estos roles en el servidor: un admin nunca ve ni toca perfiles
     * de otros administradores.
     */
    private static final Set<String> MANAGED_ROLES =
        Set.of(VACCINATOR_ROLE, READ_ONLY_ROLE);

    private final UserRepository userRepository;
    private final InstitutionRepository institutionRepository;
    private final RoleRepository roleRepository;
    private final UserRoleRepository userRoleRepository;
    private final AuthUserProvisioningClient authUserClient;
    private final IdentityService identityService;
    private final DataScope dataScope;

    public UserService(
            UserRepository userRepository,
            InstitutionRepository institutionRepository,
            RoleRepository roleRepository,
            UserRoleRepository userRoleRepository,
            AuthUserProvisioningClient authUserClient,
            IdentityService identityService,
            DataScope dataScope) {
        this.userRepository = userRepository;
        this.institutionRepository = institutionRepository;
        this.roleRepository = roleRepository;
        this.userRoleRepository = userRoleRepository;
        this.authUserClient = authUserClient;
        this.identityService = identityService;
        this.dataScope = dataScope;
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
     * Lista los usuarios de una institucion.
     *
     * <p>La autorizacion de scope vive en el servicio (no en el controller):
     * el actor se resuelve por su id y {@link DataScope} valida la institucion
     * solicitada contra la del actor para evitar un IDOR clasico
     * ({@code GET /users?institutionId=OTRA-INSTITUCION}).
     *
     * <p>Para actores restringidos (ADMIN_INSTITUTION) el listado se fuerza a
     * los roles gestionables ({@link #MANAGED_ROLES}): el parametro {@code roles}
     * del cliente se ignora, de modo que un admin no puede pedir perfiles de
     * otros administradores. Para actores con {@code INSTITUTION_WRITE} el
     * parametro {@code roles} es opcional y permite filtrar (null = todos).
     *
     * @param actorId                id del usuario autenticado
     * @param requestedInstitutionId institucion solicitada por el cliente
     * @param roles                  filtro de roles opcional (solo para
     *                               INSTITUTION_WRITE)
     */
    @Transactional(readOnly = true)
    public List<UserResponse> listByInstitution(UUID actorId, UUID requestedInstitutionId,
            Set<String> roles) {
        AuthorizedUser actor = identityService.resolve(actorId);
        InstitutionScope scope = dataScope.currentScope(actor);

        UUID institutionId = dataScope.resolveInstitutionId(actor, requestedInstitutionId);

        Set<String> effectiveRoles = scope.unrestricted()
            ? (roles == null || roles.isEmpty() ? null : roles)
            : MANAGED_ROLES;

        List<UserEntity> users = (effectiveRoles == null || effectiveRoles.isEmpty())
            ? userRepository.findByInstitutionId(institutionId)
            : userRepository.findByInstitutionIdAndRoleCodes(institutionId, effectiveRoles);
        return users.stream()
            .map(this::toResponse)
            .toList();
    }

    /**
     * Activa o desactiva un usuario.
     *
     * <p>Para actores restringidos la escritura se ejecuta con un UPDATE
     * scopeado ({@code WHERE id AND institution_id}) y el target no puede ser
     * otro administrador ni un SUPER_ADMIN. Para actores con
     * {@code INSTITUTION_WRITE} (alcance global) se opera por id.
     *
     * <p>Regla de defensa: no se puede desactivar la propia cuenta.
     */
    @Transactional
    public UserResponse updateStatus(UUID actorId, UUID userId, String status) {
        AuthorizedUser actor = identityService.resolve(actorId);
        InstitutionScope scope = dataScope.currentScope(actor);

        UserEntity.Status parsed = parseStatus(status);

        if (actorId.equals(userId) && parsed == UserEntity.Status.INACTIVE) {
            throw new IllegalArgumentException("No puedes desactivar tu propia cuenta.");
        }

        Instant now = Instant.now();

        if (scope.unrestricted()) {
            UserEntity user = findById(userId);
            user.setStatus(parsed);
            user.setUpdatedAt(now);
            return toResponse(userRepository.save(user));
        }

        UserEntity user = requireScopedManagedUser(userId, scope);
        int updated = userRepository.updateStatusScoped(
            userId, scope.institutionId(), parsed, now);
        if (updated == 0) {
            throw new ScopeViolationException(
                "El usuario no existe o no pertenece a tu institucion.");
        }
        return new UserResponse(
            user.getId(),
            user.getEmail(),
            user.getFullName(),
            user.getInstitutionId(),
            userRepository.findRolesByUserId(user.getId()).stream()
                .map(RoleEntity::getCode)
                .toList(),
            parsed.name());
    }

    /**
     * Reemplaza los roles de un usuario. El rol {@code SUPER_ADMIN} no se
     * asigna por esta via (solo roles institucionales: ADMIN_INSTITUTION,
     * VACCINATOR o READ_ONLY). Para actores restringidos el reemplazo usa
     * operaciones scopeadas por {@code institution_id}.
     */
    @Transactional
    public UserResponse updateRoles(UUID actorId, UUID userId, List<String> roleCodes) {
        AuthorizedUser actor = identityService.resolve(actorId);
        InstitutionScope scope = dataScope.currentScope(actor);

        List<RoleEntity> roles = resolveAssignableRoles(roleCodes);

        Instant now = Instant.now();

        if (scope.unrestricted()) {
            UserEntity user = findById(userId);
            replaceRoles(userId, roles);
            user.setUpdatedAt(now);
            userRepository.save(user);
            return toResponse(user);
        }

        UserEntity user = requireScopedManagedUser(userId, scope);
        userRoleRepository.deleteByUserIdScoped(userId, scope.institutionId());
        for (RoleEntity role : roles) {
            userRoleRepository.save(new UserRoleEntity(userId, role.getId()));
        }
        userRepository.touchUpdatedAtScoped(userId, scope.institutionId(), now);
        return toResponse(user);
    }

    /**
     * Carga el usuario objetivo con criterio de institucion y valida que no sea
     * un perfil privilegiado (otro administrador o SUPER_ADMIN). Para actores
     * restringidos un recurso de otra institucion se materializa como "no
     * existe" en la propia query.
     */
    private UserEntity requireScopedManagedUser(UUID userId, InstitutionScope scope) {
        UserEntity user = userRepository.findByIdAndInstitutionId(
                userId, scope.institutionId())
            .orElseThrow(() -> new ScopeViolationException(
                "El usuario no existe o no pertenece a tu institucion."));

        boolean privileged = userRepository.findRolesByUserId(userId).stream()
            .map(RoleEntity::getCode)
            .anyMatch(code -> SUPER_ADMIN_ROLE.equals(code)
                || ADMIN_INSTITUTION_ROLE.equals(code));
        if (privileged) {
            throw new ScopeViolationException(
                "No tienes permiso para administrar a otro administrador.");
        }
        return user;
    }

    /**
     * Carga un usuario por id sin alcance. Solo permitido para actores con
     * {@code INSTITUTION_WRITE}, cuyo alcance es global por diseno.
     */
    private UserEntity findById(UUID userId) {
        return userRepository.findById(userId)
            .orElseThrow(() -> new UserNotFoundException("El usuario no existe."));
    }

    private void replaceRoles(UUID userId, List<RoleEntity> roles) {
        userRoleRepository.deleteByUserId(userId);
        for (RoleEntity role : roles) {
            userRoleRepository.save(new UserRoleEntity(userId, role.getId()));
        }
    }

    private UserEntity.Status parseStatus(String status) {
        try {
            return UserEntity.Status.valueOf(status.trim().toUpperCase());
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException(
                "Estado invalido. Usa ACTIVE o INACTIVE.");
        }
    }

    private List<RoleEntity> resolveAssignableRoles(List<String> roleCodes) {
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
        return roles;
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