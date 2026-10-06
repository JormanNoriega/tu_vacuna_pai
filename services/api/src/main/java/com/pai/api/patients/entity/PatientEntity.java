package com.pai.api.patients.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Paciente registrado por una institucion. El identificador es un UUID
 * generado por el servidor; la identidad de negocio es el par
 * {@code (institution_id, document_type, document_number)}.
 *
 * <p>La entidad es plana a proposito: las tablas hijas (contactos,
 * demografia, direcciones, tutores y antecedentes) se gestionan con sus
 * propios repositorios, igual que {@code UserRoleEntity} en identity. No se
 * usan asociaciones JPA para mantener el mapeo explicito y verificable.
 */
@Entity
@Table(name = "patients", schema = "app")
public class PatientEntity {

  public enum Sex {
    MALE,
    FEMALE,
    INDETERMINATE
  }

  public enum Status {
    ACTIVE,
    INACTIVE
  }

  @Id
  private UUID id;

  @Column(name = "institution_id", nullable = false)
  private UUID institutionId;

  @Column(name = "document_type", nullable = false)
  private String documentType;

  @Column(name = "document_number", nullable = false)
  private String documentNumber;

  @Column(name = "first_name", nullable = false)
  private String firstName;

  @Column(name = "second_name")
  private String secondName;

  @Column(name = "last_name", nullable = false)
  private String lastName;

  @Column(name = "second_last_name")
  private String secondLastName;

  @Column(name = "birth_date", nullable = false)
  private LocalDate birthDate;

  @Column(name = "birth_country_id")
  private UUID birthCountryId;

  @Column(name = "birth_place")
  private String birthPlace;

  @Column(name = "migration_status")
  private String migrationStatus;

  @Column(name = "gestational_age_at_birth")
  private Integer gestationalAgeAtBirth;

  @Column(name = "vaccination_card_type")
  private String vaccinationCardType;

  @Column(name = "authorize_calls", nullable = false)
  private boolean authorizeCalls;

  @Column(name = "authorize_email", nullable = false)
  private boolean authorizeEmail;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private Sex sex;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private Status status;

  @Version
  private long version;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  protected PatientEntity() {}

  public PatientEntity(
      UUID id,
      UUID institutionId,
      String documentType,
      String documentNumber,
      String firstName,
      String lastName,
      LocalDate birthDate,
      Sex sex,
      Instant now) {
    this.id = id;
    this.institutionId = institutionId;
    this.documentType = documentType;
    this.documentNumber = documentNumber;
    this.firstName = firstName;
    this.lastName = lastName;
    this.birthDate = birthDate;
    this.sex = sex;
    this.status = Status.ACTIVE;
    this.createdAt = now;
    this.updatedAt = now;
  }

  public void updateIdentity(
      String firstName, String lastName, LocalDate birthDate, Sex sex, Instant now) {
    this.firstName = firstName;
    this.lastName = lastName;
    this.birthDate = birthDate;
    this.sex = sex;
    this.updatedAt = now;
  }

  public void setStatus(Status status, Instant now) {
    this.status = status;
    this.updatedAt = now;
  }

  /** Perfil ampliado de Fase 2 capturado por el wizard (Paso 1/2). */
  public void applyExtendedProfile(PatientExtendedProfile profile, Instant now) {
    this.secondName = profile.secondName();
    this.secondLastName = profile.secondLastName();
    this.birthCountryId = profile.birthCountryId();
    this.birthPlace = profile.birthPlace();
    this.migrationStatus = profile.migrationStatus();
    this.gestationalAgeAtBirth = profile.gestationalAgeAtBirth();
    this.vaccinationCardType = profile.vaccinationCardType();
    this.authorizeCalls = profile.authorizeCalls();
    this.authorizeEmail = profile.authorizeEmail();
    this.updatedAt = now;
  }

  public boolean isActive() {
    return status == Status.ACTIVE;
  }

  public UUID getId() {
    return id;
  }

  public UUID getInstitutionId() {
    return institutionId;
  }

  public String getDocumentType() {
    return documentType;
  }

  public String getDocumentNumber() {
    return documentNumber;
  }

  public String getFirstName() {
    return firstName;
  }

  public String getSecondName() {
    return secondName;
  }

  public String getLastName() {
    return lastName;
  }

  public String getSecondLastName() {
    return secondLastName;
  }

  public LocalDate getBirthDate() {
    return birthDate;
  }

  public UUID getBirthCountryId() {
    return birthCountryId;
  }

  public String getBirthPlace() {
    return birthPlace;
  }

  public String getMigrationStatus() {
    return migrationStatus;
  }

  public Integer getGestationalAgeAtBirth() {
    return gestationalAgeAtBirth;
  }

  public String getVaccinationCardType() {
    return vaccinationCardType;
  }

  public boolean isAuthorizeCalls() {
    return authorizeCalls;
  }

  public boolean isAuthorizeEmail() {
    return authorizeEmail;
  }

  public Sex getSex() {
    return sex;
  }

  public Status getStatus() {
    return status;
  }

  public long getVersion() {
    return version;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }

  public Instant getUpdatedAt() {
    return updatedAt;
  }
}
