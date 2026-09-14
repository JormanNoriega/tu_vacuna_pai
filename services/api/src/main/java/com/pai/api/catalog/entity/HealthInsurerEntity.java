package com.pai.api.catalog.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Aseguradora en salud (EPS) del catalogo global. Soft delete via {@code isActive}. */
@Entity
@Table(name = "health_insurers", schema = "app")
public class HealthInsurerEntity {

  @Id
  private UUID id;

  @Column(nullable = false)
  private String nit;

  @Column(nullable = false)
  private String name;

  private String code;

  @Column(name = "mobility_code")
  private String mobilityCode;

  @Column(nullable = false)
  private String regime;

  @Column(name = "is_active", nullable = false)
  private boolean active;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  protected HealthInsurerEntity() {}

  public UUID getId() {
    return id;
  }

  public String getNit() {
    return nit;
  }

  public String getName() {
    return name;
  }

  public String getCode() {
    return code;
  }

  public String getMobilityCode() {
    return mobilityCode;
  }

  public String getRegime() {
    return regime;
  }

  public boolean isActive() {
    return active;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }
}
