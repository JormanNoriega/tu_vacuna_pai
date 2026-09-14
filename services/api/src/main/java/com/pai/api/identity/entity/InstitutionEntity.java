package com.pai.api.identity.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "institutions", schema = "app")
public class InstitutionEntity {

  public enum Status {
    ACTIVE,
    INACTIVE
  }

  @Id
  private UUID id;

  @Column(nullable = false)
  private String code;

  @Column(nullable = false)
  private String name;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private Status status;

  @Column(name = "offline_window_hours", nullable = false)
  private short offlineWindowHours;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  protected InstitutionEntity() {}

  public InstitutionEntity(
      UUID id,
      String code,
      String name,
      Status status,
      short offlineWindowHours,
      Instant createdAt,
      Instant updatedAt) {
    this.id = id;
    this.code = code;
    this.name = name;
    this.status = status;
    this.offlineWindowHours = offlineWindowHours;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }

  public boolean isActive() {
    return status == Status.ACTIVE;
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

  public Status getStatus() {
    return status;
  }

  public short getOfflineWindowHours() {
    return offlineWindowHours;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }

  public void setStatus(Status status) {
    this.status = status;
  }

  public void setOfflineWindowHours(short offlineWindowHours) {
    this.offlineWindowHours = offlineWindowHours;
  }

  public void setUpdatedAt(Instant updatedAt) {
    this.updatedAt = updatedAt;
  }
}
