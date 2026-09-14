package com.pai.api.identity.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

@Entity
@Table(name = "roles", schema = "app")
public class RoleEntity {

  @Id
  private UUID id;

  @Column(nullable = false)
  private String code;

  @Column(nullable = false)
  private String name;

  protected RoleEntity() {}

  public RoleEntity(UUID id, String code, String name) {
    this.id = id;
    this.code = code;
    this.name = name;
  }

  public UUID getId() {
    return id;
  }

  public String getCode() {
    return code;
  }

  public String getName() {
    return name;
  }
}
