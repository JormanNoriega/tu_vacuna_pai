package com.pai.api.identity.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import java.util.UUID;

@Entity
@Table(name = "role_permissions", schema = "app")
@IdClass(RolePermissionId.class)
public class RolePermissionEntity {

  @Id
  private UUID roleId;

  @Id
  private UUID permissionId;

  protected RolePermissionEntity() {}

  public RolePermissionEntity(UUID roleId, UUID permissionId) {
    this.roleId = roleId;
    this.permissionId = permissionId;
  }

  public UUID getRoleId() {
    return roleId;
  }

  public UUID getPermissionId() {
    return permissionId;
  }
}
