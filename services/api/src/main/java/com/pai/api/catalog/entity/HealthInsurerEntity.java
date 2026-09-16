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

  public HealthInsurerEntity(
      UUID id,
      String nit,
      String name,
      String code,
      String mobilityCode,
      String regime,
      boolean active,
      Instant createdAt,
      Instant updatedAt) {
    this.id = id;
    this.nit = nit;
    this.name = name;
    this.code = code;
    this.mobilityCode = mobilityCode;
    this.regime = regime;
    this.active = active;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }

  /**
   * Aplica los datos del seed idempotente. No reactiva la fila ({@code active}
   * se conserva) y devuelve {@code true} solo si algun campo cambio.
   */
  public boolean applySeed(
      String name, String code, String mobilityCode, String regime, Instant now) {
    boolean changed = false;
    if (name != null && !name.equals(this.name)) {
      this.name = name;
      changed = true;
    }
    if (code != null && !code.equals(this.code)) {
      this.code = code;
      changed = true;
    }
    if (mobilityCode != null && !mobilityCode.equals(this.mobilityCode)) {
      this.mobilityCode = mobilityCode;
      changed = true;
    }
    if (regime != null && !regime.equals(this.regime)) {
      this.regime = regime;
      changed = true;
    }
    if (changed) {
      this.updatedAt = now;
    }
    return changed;
  }

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
