package com.pai.api.patients.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Afiliacion en salud del paciente (1:1): regimen y aseguradora (EPS). */
@Entity
@Table(name = "patient_affiliation", schema = "app")
public class PatientAffiliationEntity {

  @Id
  @Column(name = "patient_id")
  private UUID patientId;

  @Column(name = "affiliation_regime")
  private String affiliationRegime;

  private String insurer;

  @Column(name = "insurer_code")
  private String insurerCode;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  protected PatientAffiliationEntity() {}

  public PatientAffiliationEntity(
      UUID patientId, String affiliationRegime, String insurer, String insurerCode, Instant now) {
    this.patientId = patientId;
    this.affiliationRegime = affiliationRegime;
    this.insurer = insurer;
    this.insurerCode = insurerCode;
    this.updatedAt = now;
  }

  public UUID getPatientId() {
    return patientId;
  }

  public String getAffiliationRegime() {
    return affiliationRegime;
  }

  public String getInsurer() {
    return insurer;
  }

  public String getInsurerCode() {
    return insurerCode;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }
}
