package com.pai.api.catalog.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/** Lista de valores cerrada (catalogo de referencia). */
@Entity
@Table(name = "reference_catalogs", schema = "app")
public class ReferenceCatalogEntity {

  @Id
  private String code;

  @Column(nullable = false)
  private String name;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  protected ReferenceCatalogEntity() {}

  public String getCode() {
    return code;
  }

  public String getName() {
    return name;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }
}
