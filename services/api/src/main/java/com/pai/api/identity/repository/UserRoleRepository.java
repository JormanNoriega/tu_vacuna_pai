package com.pai.api.identity.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.pai.api.identity.entity.UserRoleEntity;
import com.pai.api.identity.entity.UserRoleId;

public interface UserRoleRepository extends JpaRepository<UserRoleEntity, UserRoleId> {

    boolean existsByUserId(UUID userId);
}
