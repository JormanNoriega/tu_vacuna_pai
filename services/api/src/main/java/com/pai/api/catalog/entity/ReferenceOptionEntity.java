package com.pai.api.catalog.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Opcion de un catalogo de referencia. */
@Entity
@Table(name = "reference_options", schema = "app")
public class ReferenceOptionEntity {

  @Id
  @GeneratedValue
  private UUID id;

  @Column(name = "catalog_code", nullable = false)
  private String catalogCode;

  @Column(nullable = false)
  private String code;

  @Column(nullable = false)
  private String label;

  @Column(name = "sort_order", nullable = false)
  private int sortOrder;

  @Column(name = "is_active", nullable = false)
  private boolean active;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  protected ReferenceOptionEntity() {}

  public UUID getId() {
    return id;
  }

  public String getCatalogCode() {
    return catalogCode;
  }

  public String getCode() {
    return code;
  }

  public String getLabel() {
    return label;
  }

  public int getSortOrder() {
    return sortOrder;
  }

  public boolean isActive() {
    return active;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }
}
