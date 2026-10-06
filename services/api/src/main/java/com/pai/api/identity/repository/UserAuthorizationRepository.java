package com.pai.api.identity.repository;

import com.pai.api.identity.entity.PermissionEntity;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

/**
 * Consultas de autorizacion (roles y permisos) de los usuarios. Separadas de
 * {@link UserRepository} (ISP): la gestion de usuarios y la resolucion de
 * permisos son responsabilidades distintas.
 */
public interface UserAuthorizationRepository extends Repository<UserEntity, UUID> {

  @Query("""
      SELECT r FROM RoleEntity r
      JOIN UserRoleEntity ur ON ur.roleId = r.id
      WHERE ur.userId = :userId
      ORDER BY r.code
      """)
  List<RoleEntity> findRolesByUserId(@Param("userId") UUID userId);

  @Query("""
      SELECT DISTINCT p FROM PermissionEntity p
      JOIN RolePermissionEntity rp ON rp.permissionId = p.id
      JOIN UserRoleEntity ur ON ur.roleId = rp.roleId
      WHERE ur.userId = :userId
      ORDER BY p.code
      """)
  List<PermissionEntity> findPermissionsByUserId(@Param("userId") UUID userId);

  /** Roles de varios usuarios en una sola consulta (evita el N+1 del listado). */
  @Query("""
      SELECT ur.userId AS userId, r.code AS code
      FROM UserRoleEntity ur
      JOIN RoleEntity r ON r.id = ur.roleId
      WHERE ur.userId IN :userIds
      ORDER BY ur.userId, r.code
      """)
  List<UserRoleCode> findRoleCodesByUserIds(@Param("userIds") Collection<UUID> userIds);

  /** Proyeccion (userId, codigo de rol). */
  interface UserRoleCode {
    UUID getUserId();

    String getCode();
  }
}
