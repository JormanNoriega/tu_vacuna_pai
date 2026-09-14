package com.pai.api.identity.repository;

import com.pai.api.identity.entity.UserRoleEntity;
import com.pai.api.identity.entity.UserRoleId;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * Acceso a {@link UserRoleEntity}. La eliminacion de roles de un usuario solo
 * se permite si el usuario pertenece a la institucion indicada (el criterio de
 * alcance vive en la propia query).
 */
public interface UserRoleRepository extends JpaRepository<UserRoleEntity, UserRoleId> {

  boolean existsByUserId(UUID userId);

  void deleteByUserId(UUID userId);

  /**
   * Elimina los roles de un usuario solo si este pertenece a la institucion.
   * Devuelve 0 si el usuario esta fuera del alcance.
   */
  @Modifying
  @Query("""
      DELETE FROM UserRoleEntity ur
      WHERE ur.userId = :userId
        AND EXISTS (SELECT 1 FROM UserEntity u
                    WHERE u.id = :userId AND u.institutionId = :institutionId)
      """)
  int deleteByUserIdScoped(
      @Param("userId") UUID userId, @Param("institutionId") UUID institutionId);
}
