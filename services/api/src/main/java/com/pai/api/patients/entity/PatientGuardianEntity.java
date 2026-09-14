package com.pai.api.patients.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Tutor o responsable de un paciente (madre, padre, cuidador u otro). */
@Entity
@Table(name = "patient_guardians", schema = "app")
public class PatientGuardianEntity {

  public enum Relationship {
    MOTHER,
    FATHER,
    CAREGIVER,
    OTHER
  }

  @Id
  private UUID id;

  @Column(name = "patient_id", nullable = false)
  private UUID patientId;

  @Column(nullable = false)
  private String relationship;

  @Column(name = "full_name", nullable = false)
  private String fullName;

  @Column(name = "second_name")
  private String secondName;

  @Column(name = "second_last_name")
  private String secondLastName;

  @Column(name = "document_type")
  private String documentType;

  @Column(name = "document_number")
  private String documentNumber;

  private String phone;

  private String landline;

  private String cellphone;

  private String email;

  @Column(name = "affiliation_regime")
  private String affiliationRegime;

  private String insurer;

  @Column(name = "insurer_code")
  private String insurerCode;

  private String ethnicity;

  private Boolean displaced;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  protected PatientGuardianEntity() {}

  public PatientGuardianEntity(
      UUID id,
      UUID patientId,
      Relationship relationship,
      String fullName,
      String documentType,
      String documentNumber,
      String phone,
      Instant now) {
    this(
        id,
        patientId,
        relationship,
        fullName,
        null,
        null,
        documentType,
        documentNumber,
        phone,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        now);
  }

  public PatientGuardianEntity(
      UUID id,
      UUID patientId,
      Relationship relationship,
      String fullName,
      String secondName,
      String secondLastName,
      String documentType,
      String documentNumber,
      String phone,
      String landline,
      String cellphone,
      String email,
      String affiliationRegime,
      String insurer,
      String insurerCode,
      String ethnicity,
      Boolean displaced,
      Instant now) {
    this.id = id;
    this.patientId = patientId;
    this.relationship = relationship.name();
    this.fullName = fullName;
    this.secondName = secondName;
    this.secondLastName = secondLastName;
    this.documentType = documentType;
    this.documentNumber = documentNumber;
    this.phone = phone;
    this.landline = landline;
    this.cellphone = cellphone;
    this.email = email;
    this.affiliationRegime = affiliationRegime;
    this.insurer = insurer;
    this.insurerCode = insurerCode;
    this.ethnicity = ethnicity;
    this.displaced = displaced;
    this.createdAt = now;
  }

  public String getSecondName() {
    return secondName;
  }

  public String getSecondLastName() {
    return secondLastName;
  }

  public String getLandline() {
    return landline;
  }

  public String getCellphone() {
    return cellphone;
  }

  public String getEmail() {
    return email;
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

  public String getEthnicity() {
    return ethnicity;
  }

  public Boolean getDisplaced() {
    return displaced;
  }

  public UUID getId() {
    return id;
  }

  public UUID getPatientId() {
    return patientId;
  }

  public String getRelationship() {
    return relationship;
  }

  public String getFullName() {
    return fullName;
  }

  public String getDocumentType() {
    return documentType;
  }

  public String getDocumentNumber() {
    return documentNumber;
  }

  public String getPhone() {
    return phone;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }
}
