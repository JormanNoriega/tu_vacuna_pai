package com.pai.api.identity.service;

import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.entity.UserRoleEntity;
import com.pai.api.identity.exception.RoleNotFoundException;
import com.pai.api.identity.exception.UserNotFoundException;
import com.pai.api.identity.repository.RoleRepository;
import com.pai.api.identity.repository.UserAuthorizationRepository;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.identity.repository.UserRoleRepository;
import com.pai.api.shared.exceptions.ScopeViolationException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Gestion de usuarios administrativos (listado, estado y roles). La creacion de
 * usuarios (con su compensacion distribuida) vive en
 * {@link UserProvisioningService}.
 *
 * <p>El alcance institucional se deriva del actor via {@link DataScope}
 * (equivalente a RLS en la capa de datos): las lecturas y escrituras de
 * usuarios usan consultas scopeadas por {@code institution_id}, de modo que un
 * recurso de otra institucion nunca se materializa ni se modifica.
 */
@Service
public class UserService {

  /**
   * Roles que un ADMIN_INSTITUTION administra. El listado de gestion se
   * fuerza a estos roles en el servidor: un admin nunca ve ni toca perfiles
   * de otros administradores.
   */
  private static final Set<String> MANAGED_ROLES =
      Set.of(RoleCodes.VACCINATOR, RoleCodes.READ_ONLY);

  private final UserRepository userRepository;
  private final RoleRepository roleRepository;
  private final UserRoleRepository userRoleRepository;
  private final UserAuthorizationRepository authorizationRepository;
  private final IdentityService identityService;
  private final DataScope dataScope;
  private final IdentityMapper mapper;

  public UserService(
      UserRepository userRepository,
      RoleRepository roleRepository,
      UserRoleRepository userRoleRepository,
      UserAuthorizationRepository authorizationRepository,
      IdentityService identityService,
      DataScope dataScope,
      IdentityMapper mapper) {
    this.userRepository = userRepository;
    this.roleRepository = roleRepository;
    this.userRoleRepository = userRoleRepository;
    this.authorizationRepository = authorizationRepository;
    this.identityService = identityService;
    this.dataScope = dataScope;
    this.mapper = mapper;
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
  public List<UserResponse> listByInstitution(
      UUID actorId, UUID requestedInstitutionId, Set<String> roles) {
    AuthorizedUser actor = identityService.resolve(actorId);
    InstitutionScope scope = dataScope.currentScope(actor);

    UUID institutionId = dataScope.resolveInstitutionId(actor, requestedInstitutionId);

    Set<String> effectiveRoles =
        scope.unrestricted() ? (roles == null || roles.isEmpty() ? null : roles) : MANAGED_ROLES;

    List<UserEntity> users = (effectiveRoles == null || effectiveRoles.isEmpty())
        ? userRepository.findByInstitutionId(institutionId)
        : userRepository.findByInstitutionIdAndRoleCodes(institutionId, effectiveRoles);
    Map<UUID, List<String>> rolesByUser = roleCodesByUser(users);
    return users.stream()
        .map(user -> mapper.toUserResponse(user, rolesByUser.getOrDefault(user.getId(), List.of())))
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

    UserEntity.Status parsed = IdentityRules.parseUserStatus(status);

    if (actorId.equals(userId) && parsed == UserEntity.Status.INACTIVE) {
      throw new IllegalArgumentException("No puedes desactivar tu propia cuenta.");
    }

    Instant now = Instant.now();

    if (scope.unrestricted()) {
      UserEntity user = findById(userId);
      user.setStatus(parsed);
      user.setUpdatedAt(now);
      return mapper.toUserResponse(userRepository.save(user), roleCodesOf(userId));
    }

    UserEntity user = requireScopedManagedUser(userId, scope);
    int updated = userRepository.updateStatusScoped(userId, scope.institutionId(), parsed, now);
    if (updated == 0) {
      throw new ScopeViolationException("El usuario no existe o no pertenece a tu institucion.");
    }
    return mapper.toUserResponse(user, parsed.name(), roleCodesOf(userId));
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
      return mapper.toUserResponse(user, roleCodesOf(userId));
    }

    UserEntity user = requireScopedManagedUser(userId, scope);
    userRoleRepository.deleteByUserIdScoped(userId, scope.institutionId());
    for (RoleEntity role : roles) {
      userRoleRepository.save(new UserRoleEntity(userId, role.getId()));
    }
    userRepository.touchUpdatedAtScoped(userId, scope.institutionId(), now);
    return mapper.toUserResponse(user, roleCodesOf(userId));
  }

  /**
   * Carga el usuario objetivo con criterio de institucion y valida que no sea
   * un perfil privilegiado (otro administrador o SUPER_ADMIN). Para actores
   * restringidos un recurso de otra institucion se materializa como "no
   * existe" en la propia query.
   */
  private UserEntity requireScopedManagedUser(UUID userId, InstitutionScope scope) {
    UserEntity user = userRepository
        .findByIdAndInstitutionId(userId, scope.institutionId())
        .orElseThrow(() ->
            new ScopeViolationException("El usuario no existe o no pertenece a tu institucion."));

    boolean privileged = roleCodesOf(userId).stream()
        .anyMatch(
            code -> RoleCodes.SUPER_ADMIN.equals(code) || RoleCodes.ADMIN_INSTITUTION.equals(code));
    if (privileged) {
      throw new ScopeViolationException("No tienes permiso para administrar a otro administrador.");
    }
    return user;
  }

  /** Codigos de rol vigentes de un usuario. */
  private List<String> roleCodesOf(UUID userId) {
    return authorizationRepository.findRolesByUserId(userId).stream()
        .map(RoleEntity::getCode)
        .toList();
  }

  /** Codigos de rol de varios usuarios en una sola consulta (evita N+1). */
  private Map<UUID, List<String>> roleCodesByUser(List<UserEntity> users) {
    if (users.isEmpty()) {
      return Map.of();
    }
    List<UUID> userIds = users.stream().map(UserEntity::getId).toList();
    return authorizationRepository.findRoleCodesByUserIds(userIds).stream()
        .collect(Collectors.groupingBy(
            UserAuthorizationRepository.UserRoleCode::getUserId,
            Collectors.mapping(
                UserAuthorizationRepository.UserRoleCode::getCode, Collectors.toList())));
  }

  /**
   * Carga un usuario por id sin alcance. Solo permitido para actores con
   * {@code INSTITUTION_WRITE}, cuyo alcance es global por diseno.
   */
  private UserEntity findById(UUID userId) {
    return userRepository
        .findById(userId)
        .orElseThrow(() -> new UserNotFoundException("El usuario no existe."));
  }

  private void replaceRoles(UUID userId, List<RoleEntity> roles) {
    userRoleRepository.deleteByUserId(userId);
    for (RoleEntity role : roles) {
      userRoleRepository.save(new UserRoleEntity(userId, role.getId()));
    }
  }

  private List<RoleEntity> resolveAssignableRoles(List<String> roleCodes) {
    List<RoleEntity> roles = new ArrayList<>(roleCodes.size());
    for (String code : roleCodes) {
      String normalized = code.trim().toUpperCase();
      if (RoleCodes.SUPER_ADMIN.equals(normalized)) {
        throw new IllegalArgumentException(
            "El rol SUPER_ADMIN no se puede asignar desde la aplicacion.");
      }
      RoleEntity role = roleRepository
          .findByCode(normalized)
          .orElseThrow(
              () -> new RoleNotFoundException("El rol " + normalized + " no esta configurado."));
      roles.add(role);
    }
    return roles;
  }
}
