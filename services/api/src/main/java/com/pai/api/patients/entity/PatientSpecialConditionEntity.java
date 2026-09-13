package com.pai.api.patients.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Condiciones especiales del paciente (1:1). */
@Entity
@Table(name = "patient_special_conditions", schema = "app")
public class PatientSpecialConditionEntity {

    @Id
    @Column(name = "patient_id")
    private UUID patientId;

    private boolean displaced;

    private boolean disabled;

    private boolean deceased;

    @Column(name = "armed_conflict_victim")
    private boolean armedConflictVictim;

    @Column(name = "currently_studying")
    private Boolean currentlyStudying;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected PatientSpecialConditionEntity() {}

    public PatientSpecialConditionEntity(
            UUID patientId,
            boolean displaced,
            boolean disabled,
            boolean deceased,
            boolean armedConflictVictim,
            Boolean currentlyStudying,
            Instant now) {
        this.patientId = patientId;
        this.displaced = displaced;
        this.disabled = disabled;
        this.deceased = deceased;
        this.armedConflictVictim = armedConflictVictim;
        this.currentlyStudying = currentlyStudying;
        this.updatedAt = now;
    }

    public UUID getPatientId() {
        return patientId;
    }

    public boolean isDisplaced() {
        return displaced;
    }

    public boolean isDisabled() {
        return disabled;
    }

    public boolean isDeceased() {
        return deceased;
    }

    public boolean isArmedConflictVictim() {
        return armedConflictVictim;
    }

    public Boolean getCurrentlyStudying() {
        return currentlyStudying;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
