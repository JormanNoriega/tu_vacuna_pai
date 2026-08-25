package com.pai.api.identity.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.pai.api.identity.entity.PermissionEntity;
import com.pai.api.identity.entity.RoleEntity;
import com.pai.api.identity.entity.UserEntity;

public interface UserRepository extends JpaRepository<UserEntity, UUID> {

    Optional<UserEntity> findByEmail(String email);

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