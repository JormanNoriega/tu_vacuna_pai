package com.pai.api.catalog.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "vaccine_options", schema = "app")
public class VaccineOptionEntity {
    @Id
    private UUID id;

    @Column(name = "vaccine_id", nullable = false)
    private UUID vaccineId;

    @Column(name = "field_type", nullable = false)
    private String fieldType;

    @Column(nullable = false)
    private String value;

    @Column(name = "value_normalized", insertable = false, updatable = false)
    private String valueNormalized;

    @Column(name = "display_name", nullable = false)
    private String displayName;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Column(name = "is_default", nullable = false)
    private boolean isDefault;

    @Column(name = "is_active", nullable = false)
    private boolean active;

    @Version
    private long version;

    @Column(name = "created_by", nullable = false, updatable = false)
    private UUID createdBy;

    @Column(name = "updated_by", nullable = false)
    private UUID updatedBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected VaccineOptionEntity() {}

    public VaccineOptionEntity(
            UUID id,
            UUID vaccineId,
            String type,
            String value,
            String display,
            int order,
            boolean def,
            UUID actor,
            Instant now) {
        this.id = id;
        this.vaccineId = vaccineId;
        fieldType = type;
        this.value = value;
        displayName = display;
        sortOrder = order;
        isDefault = def;
        active = true;
        createdBy = actor;
        updatedBy = actor;
        createdAt = now;
        updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getVaccineId() {
        return vaccineId;
    }

    public String getFieldType() {
        return fieldType;
    }

    public String getValue() {
        return value;
    }

    public String getDisplayName() {
        return displayName;
    }

    public int getSortOrder() {
        return sortOrder;
    }

    public boolean isDefault() {
        return isDefault;
    }

    public boolean isActive() {
        return active;
    }

    public long getVersion() {
        return version;
    }

    public String getValueNormalized() {
        return valueNormalized;
    }

    public void update(String value, String display, int order, boolean def, boolean active, UUID actor) {
        this.value = value;
        displayName = display;
        sortOrder = order;
        isDefault = def;
        this.active = active;
        updatedBy = actor;
        updatedAt = Instant.now();
    }
}
