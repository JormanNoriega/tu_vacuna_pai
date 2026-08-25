package com.pai.api.identity.entity;

import java.util.UUID;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;

@Entity
@Table(name = "user_roles", schema = "app")
@IdClass(UserRoleId.class)
public class UserRoleEntity {

    @Id
    private UUID userId;

    @Id
    private UUID roleId;

    protected UserRoleEntity() {
    }

    public UserRoleEntity(UUID userId, UUID roleId) {
        this.userId = userId;
        this.roleId = roleId;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getRoleId() {
        return roleId;
    }
}