package com.pai.api.patients.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/** Condicion de la usuaria y datos obstetricos/natales (1:1). */
@Entity
@Table(name = "patient_user_condition", schema = "app")
public class PatientUserConditionEntity {

    @Id
    @Column(name = "patient_id")
    private UUID patientId;

    @Column(name = "user_condition")
    private String userCondition;

    @Column(name = "last_menstrual_date")
    private LocalDate lastMenstrualDate;

    @Column(name = "gestation_weeks")
    private Integer gestationWeeks;

    @Column(name = "probable_delivery_date")
    private LocalDate probableDeliveryDate;

    @Column(name = "previous_pregnancies")
    private Integer previousPregnancies;

    @Column(name = "has_given_birth")
    private Boolean hasGivenBirth;

    @Column(name = "birth_place_delivery")
    private String birthPlaceDelivery;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected PatientUserConditionEntity() {}

    public PatientUserConditionEntity(
            UUID patientId,
            String userCondition,
            LocalDate lastMenstrualDate,
            Integer gestationWeeks,
            LocalDate probableDeliveryDate,
            Integer previousPregnancies,
            Boolean hasGivenBirth,
            String birthPlaceDelivery,
            Instant now) {
        this.patientId = patientId;
        this.userCondition = userCondition;
        this.lastMenstrualDate = lastMenstrualDate;
        this.gestationWeeks = gestationWeeks;
        this.probableDeliveryDate = probableDeliveryDate;
        this.previousPregnancies = previousPregnancies;
        this.hasGivenBirth = hasGivenBirth;
        this.birthPlaceDelivery = birthPlaceDelivery;
        this.updatedAt = now;
    }

    public UUID getPatientId() {
        return patientId;
    }

    public String getUserCondition() {
        return userCondition;
    }

    public LocalDate getLastMenstrualDate() {
        return lastMenstrualDate;
    }

    public Integer getGestationWeeks() {
        return gestationWeeks;
    }

    public LocalDate getProbableDeliveryDate() {
        return probableDeliveryDate;
    }

    public Integer getPreviousPregnancies() {
        return previousPregnancies;
    }

    public Boolean getHasGivenBirth() {
        return hasGivenBirth;
    }

    public String getBirthPlaceDelivery() {
        return birthPlaceDelivery;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
