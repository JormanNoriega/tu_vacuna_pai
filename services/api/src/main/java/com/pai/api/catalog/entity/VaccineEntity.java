package com.pai.api.catalog.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "vaccines", schema = "app")
public class VaccineEntity {
    @Id
    private UUID id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, updatable = false)
    private String code;

    @Column(nullable = false)
    private String category;

    @Column(name = "max_doses", nullable = false)
    private short maxDoses;

    @Column(name = "min_age_months")
    private Integer minAgeMonths;

    @Column(name = "max_age_months")
    private Integer maxAgeMonths;

    @Column(name = "has_laboratory")
    private boolean hasLaboratory;

    @Column(name = "has_lot")
    private boolean hasLot;

    @Column(name = "has_syringe")
    private boolean hasSyringe;

    @Column(name = "has_syringe_lot")
    private boolean hasSyringeLot;

    @Column(name = "has_diluent")
    private boolean hasDiluent;

    @Column(name = "has_dropper")
    private boolean hasDropper;

    @Column(name = "has_pneumococcal_type")
    private boolean hasPneumococcalType;

    @Column(name = "has_vial_count")
    private boolean hasVialCount;

    @Column(name = "has_observation")
    private boolean hasObservation;

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

    protected VaccineEntity() {}

    public VaccineEntity(
            UUID id,
            String name,
            String code,
            String category,
            short maxDoses,
            Integer min,
            Integer max,
            UUID actor,
            Instant now) {
        this.id = id;
        this.name = name;
        this.code = code;
        this.category = category;
        this.maxDoses = maxDoses;
        this.minAgeMonths = min;
        this.maxAgeMonths = max;
        this.active = true;
        this.createdBy = actor;
        this.updatedBy = actor;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getCode() {
        return code;
    }

    public String getCategory() {
        return category;
    }

    public short getMaxDoses() {
        return maxDoses;
    }

    public Integer getMinAgeMonths() {
        return minAgeMonths;
    }

    public Integer getMaxAgeMonths() {
        return maxAgeMonths;
    }

    public boolean isActive() {
        return active;
    }

    public long getVersion() {
        return version;
    }

    public UUID getCreatedBy() {
        return createdBy;
    }

    public UUID getUpdatedBy() {
        return updatedBy;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public boolean hasLaboratory() {
        return hasLaboratory;
    }

    public boolean hasLot() {
        return hasLot;
    }

    public boolean hasSyringe() {
        return hasSyringe;
    }

    public boolean hasSyringeLot() {
        return hasSyringeLot;
    }

    public boolean hasDiluent() {
        return hasDiluent;
    }

    public boolean hasDropper() {
        return hasDropper;
    }

    public boolean hasPneumococcalType() {
        return hasPneumococcalType;
    }

    public boolean hasVialCount() {
        return hasVialCount;
    }

    public boolean hasObservation() {
        return hasObservation;
    }

    public void update(
            String name, String category, short doses, Integer min, Integer max, boolean active, UUID actor) {
        this.name = name;
        this.category = category;
        this.maxDoses = doses;
        this.minAgeMonths = min;
        this.maxAgeMonths = max;
        this.active = active;
        this.updatedBy = actor;
        this.updatedAt = Instant.now();
    }

    public void setLegacyFlags(
            boolean laboratory,
            boolean lot,
            boolean syringe,
            boolean syringeLot,
            boolean diluent,
            boolean dropper,
            boolean pneumococcal,
            boolean vialCount,
            boolean observation) {
        hasLaboratory = laboratory;
        hasLot = lot;
        hasSyringe = syringe;
        hasSyringeLot = syringeLot;
        hasDiluent = diluent;
        hasDropper = dropper;
        hasPneumococcalType = pneumococcal;
        hasVialCount = vialCount;
        hasObservation = observation;
    }
}
