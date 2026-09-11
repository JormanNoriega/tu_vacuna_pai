package com.pai.api.identity.repository;

import com.pai.api.identity.entity.PermissionEntity;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * Acceso a {@link UserEntity}. Regla de alcance (equivalente a RLS en la capa
 * de datos): los recursos institucionales se leen y modifican SIEMPRE con
 * criterio de institucion. No se exponen operaciones individuales por id sin
 * alcance para rutas administrativas o clinicas; para eso existen
 * {@link #findByIdAndInstitutionId}, {@link #updateStatusScoped} y
 * {@link #touchUpdatedAtScoped}. Las operaciones globales por id
 * ({@code findById}, {@code save}) quedan reservadas a actores con
 * {@code INSTITUTION_WRITE}.
 */
public interface UserRepository extends JpaRepository<UserEntity, UUID> {

    Optional<UserEntity> findByEmail(String email);

    List<UserEntity> findByInstitutionId(UUID institutionId);

    /**
     * Carga un usuario solo si pertenece a la institucion indicada. Devuelve
     * vacio cuando el usuario no existe o esta fuera del alcance, de modo que
     * una query nunca materializa un recurso de otra institucion.
     */
    Optional<UserEntity> findByIdAndInstitutionId(UUID id, UUID institutionId);

    /**
     * Lista los usuarios de la institucion con alguno de los roles indicados.
     * Se usa para el listado de gestion, que solo expone los roles
     * administrables (VACCINATOR, READ_ONLY).
     */
    @Query("""
        SELECT DISTINCT u FROM UserEntity u
        JOIN UserRoleEntity ur ON ur.userId = u.id
        JOIN RoleEntity r ON r.id = ur.roleId
        WHERE u.institutionId = :institutionId
          AND r.code IN :roleCodes
        ORDER BY u.fullName
        """)
    List<UserEntity> findByInstitutionIdAndRoleCodes(
            @Param("institutionId") UUID institutionId, @Param("roleCodes") Collection<String> roleCodes);

    /**
     * Actualiza el estado de un usuario con la institucion en el propio WHERE:
     * si el usuario no pertenece a la institucion devuelve 0 y no modifica nada.
     */
    @Modifying
    @Query("""
        UPDATE UserEntity u
        SET u.status = :status, u.updatedAt = :updatedAt
        WHERE u.id = :id AND u.institutionId = :institutionId
        """)
    int updateStatusScoped(
            @Param("id") UUID id,
            @Param("institutionId") UUID institutionId,
            @Param("status") UserEntity.Status status,
            @Param("updatedAt") Instant updatedAt);

    /**
     * Marca la fecha de actualizacion con la institucion en el propio WHERE.
     */
    @Modifying
    @Query("""
        UPDATE UserEntity u
        SET u.updatedAt = :updatedAt
        WHERE u.id = :id AND u.institutionId = :institutionId
        """)
    int touchUpdatedAtScoped(
            @Param("id") UUID id, @Param("institutionId") UUID institutionId, @Param("updatedAt") Instant updatedAt);

    boolean existsByEmail(String email);

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
}
