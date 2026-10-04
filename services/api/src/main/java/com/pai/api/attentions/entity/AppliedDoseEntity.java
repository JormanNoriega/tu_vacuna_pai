package com.pai.api.attentions.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * Dosis aplicada dentro de una atencion. Es append-only: no admite UPDATE ni
 * DELETE; una correccion se representa con una cancelacion (motivo, actor,
 * timestamp) y, si corresponde, una nueva dosis.
 *
 * <p>Guarda snapshot del catalogo vigente al momento del registro
 * (nombre/codigo de vacuna, etiqueta de dosis, tipo de neumococo y opciones
 * operativas elegidas) para que el historial no cambie si el catalogo se
 * modifica despues.
 */
@Entity
@Table(name = "applied_doses", schema = "app")
public class AppliedDoseEntity {

  public enum Status {
    REGISTERED,
    CANCELLED
  }

  @Id
  private UUID id;

  @Column(name = "attention_id", nullable = false)
  private UUID attentionId;

  @Column(name = "vaccine_id", nullable = false)
  private UUID vaccineId;

  @Column(name = "lot_id")
  private UUID lotId;

  @Column(name = "lot_number")
  private String lotNumber;

  @Column(name = "application_date", nullable = false)
  private Instant applicationDate;

  @Column(name = "dose_option_id")
  private UUID doseOptionId;

  @Column(name = "pneumococcal_type_option_id")
  private UUID pneumococcalTypeOptionId;

  @Column(name = "vaccine_name_snapshot", nullable = false)
  private String vaccineNameSnapshot;

  @Column(name = "vaccine_code_snapshot", nullable = false)
  private String vaccineCodeSnapshot;

  @Column(name = "dose_label_snapshot", nullable = false)
  private String doseLabelSnapshot;

  @Column(name = "dose_value_snapshot")
  private String doseValueSnapshot;

  @Column(name = "pneumococcal_type_snapshot")
  private String pneumococcalTypeSnapshot;

  @Column(name = "catalog_version", nullable = false)
  private long catalogVersion;

  @Column(name = "selected_laboratory_id")
  private UUID selectedLaboratoryId;

  @Column(name = "selected_laboratory_snapshot")
  private String selectedLaboratorySnapshot;

  @Column(name = "selected_syringe_id")
  private UUID selectedSyringeId;

  @Column(name = "selected_syringe_snapshot")
  private String selectedSyringeSnapshot;

  @Column(name = "selected_dropper_id")
  private UUID selectedDropperId;

  @Column(name = "selected_dropper_snapshot")
  private String selectedDropperSnapshot;

  @Column(name = "selected_observation_id")
  private UUID selectedObservationId;

  @Column(name = "selected_observation_snapshot")
  private String selectedObservationSnapshot;

  @Column(name = "syringe_lot")
  private String syringeLot;

  private String diluent;

  @Column(name = "vial_count")
  private Integer vialCount;

  @Column(name = "custom_observation")
  private String customObservation;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private Status status;

  @Column(name = "cancelled_reason")
  private String cancelledReason;

  @Column(name = "cancelled_by")
  private UUID cancelledBy;

  @Column(name = "cancelled_at")
  private Instant cancelledAt;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  protected AppliedDoseEntity() {}

  public static Builder builder() {
    return new Builder();
  }

  /**
   * Construction por pasos de una dosis nueva. Centraliza los valores por
   * defecto (id autogenerado, estado {@code REGISTERED}, {@code createdAt}) y
   * valida los campos requeridos del agregado, reemplazando el constructor
   * telescopico de 23 argumentos y la inicializacion en dos fases
   * ({@code applyOperationalFields}). La entidad no depende de tipos de la capa
   * de servicio: el Builder recibe datos primitivos del dominio.
   */
  public static final class Builder {
    private UUID id;
    private UUID attentionId;
    private Instant applicationDate;
    private UUID vaccineId;
    private String vaccineNameSnapshot;
    private String vaccineCodeSnapshot;
    private long catalogVersion;
    private UUID doseOptionId;
    private String doseLabelSnapshot;
    private String doseValueSnapshot;
    private UUID pneumococcalTypeOptionId;
    private String pneumococcalTypeSnapshot;
    private UUID lotId;
    private String lotNumber;
    private UUID selectedLaboratoryId;
    private String selectedLaboratorySnapshot;
    private UUID selectedSyringeId;
    private String selectedSyringeSnapshot;
    private UUID selectedDropperId;
    private String selectedDropperSnapshot;
    private UUID selectedObservationId;
    private String selectedObservationSnapshot;
    private String syringeLot;
    private String diluent;
    private Integer vialCount;
    private String customObservation;

    private Builder() {}

    public Builder id(UUID id) {
      this.id = id;
      return this;
    }

    public Builder attentionId(UUID attentionId) {
      this.attentionId = attentionId;
      return this;
    }

    public Builder applicationDate(Instant applicationDate) {
      this.applicationDate = applicationDate;
      return this;
    }

    public Builder lot(UUID lotId, String lotNumber) {
      this.lotId = lotId;
      this.lotNumber = lotNumber;
      return this;
    }

    public Builder vaccine(UUID vaccineId, String name, String code, long catalogVersion) {
      this.vaccineId = vaccineId;
      this.vaccineNameSnapshot = name;
      this.vaccineCodeSnapshot = code;
      this.catalogVersion = catalogVersion;
      return this;
    }

    public Builder dose(UUID doseOptionId, String label, String value) {
      this.doseOptionId = doseOptionId;
      this.doseLabelSnapshot = label;
      this.doseValueSnapshot = value;
      return this;
    }

    public Builder pneumococcal(UUID optionId, String snapshot) {
      this.pneumococcalTypeOptionId = optionId;
      this.pneumococcalTypeSnapshot = snapshot;
      return this;
    }

    public Builder laboratory(UUID id, String snapshot) {
      this.selectedLaboratoryId = id;
      this.selectedLaboratorySnapshot = snapshot;
      return this;
    }

    public Builder syringe(UUID id, String snapshot) {
      this.selectedSyringeId = id;
      this.selectedSyringeSnapshot = snapshot;
      return this;
    }

    public Builder dropper(UUID id, String snapshot) {
      this.selectedDropperId = id;
      this.selectedDropperSnapshot = snapshot;
      return this;
    }

    public Builder observation(UUID id, String snapshot) {
      this.selectedObservationId = id;
      this.selectedObservationSnapshot = snapshot;
      return this;
    }

    /** Campos operativos opcionales capturados por el wizard (Paso 3). */
    public Builder operational(
        String syringeLot, String diluent, Integer vialCount, String customObservation) {
      this.syringeLot = syringeLot;
      this.diluent = diluent;
      this.vialCount = vialCount;
      this.customObservation = customObservation;
      return this;
    }

    public AppliedDoseEntity build() {
      if (attentionId == null) {
        throw new IllegalStateException("attentionId es obligatorio.");
      }
      if (vaccineId == null) {
        throw new IllegalStateException("vaccineId es obligatorio.");
      }
      if (vaccineNameSnapshot == null) {
        throw new IllegalStateException("vaccineNameSnapshot es obligatorio.");
      }
      if (vaccineCodeSnapshot == null) {
        throw new IllegalStateException("vaccineCodeSnapshot es obligatorio.");
      }
      if (doseLabelSnapshot == null) {
        throw new IllegalStateException("doseLabelSnapshot es obligatorio.");
      }

      Instant now = Instant.now();
      AppliedDoseEntity dose = new AppliedDoseEntity();
      dose.id = id != null ? id : UUID.randomUUID();
      dose.attentionId = attentionId;
      dose.vaccineId = vaccineId;
      dose.applicationDate = applicationDate != null ? applicationDate : now;
      dose.vaccineNameSnapshot = vaccineNameSnapshot;
      dose.vaccineCodeSnapshot = vaccineCodeSnapshot;
      dose.catalogVersion = catalogVersion;
      dose.doseOptionId = doseOptionId;
      dose.doseLabelSnapshot = doseLabelSnapshot;
      dose.doseValueSnapshot = doseValueSnapshot;
      dose.pneumococcalTypeOptionId = pneumococcalTypeOptionId;
      dose.pneumococcalTypeSnapshot = pneumococcalTypeSnapshot;
      dose.lotId = lotId;
      dose.lotNumber = lotNumber;
      dose.selectedLaboratoryId = selectedLaboratoryId;
      dose.selectedLaboratorySnapshot = selectedLaboratorySnapshot;
      dose.selectedSyringeId = selectedSyringeId;
      dose.selectedSyringeSnapshot = selectedSyringeSnapshot;
      dose.selectedDropperId = selectedDropperId;
      dose.selectedDropperSnapshot = selectedDropperSnapshot;
      dose.selectedObservationId = selectedObservationId;
      dose.selectedObservationSnapshot = selectedObservationSnapshot;
      dose.syringeLot = syringeLot;
      dose.diluent = diluent;
      dose.vialCount = vialCount;
      dose.customObservation = customObservation;
      dose.status = Status.REGISTERED;
      dose.createdAt = now;
      return dose;
    }
  }

  public void cancel(String reason, UUID actorId, Instant now) {
    this.status = Status.CANCELLED;
    this.cancelledReason = reason;
    this.cancelledBy = actorId;
    this.cancelledAt = now;
  }

  public String getSyringeLot() {
    return syringeLot;
  }

  public String getDiluent() {
    return diluent;
  }

  public Integer getVialCount() {
    return vialCount;
  }

  public String getCustomObservation() {
    return customObservation;
  }

  public UUID getId() {
    return id;
  }

  public UUID getAttentionId() {
    return attentionId;
  }

  public UUID getVaccineId() {
    return vaccineId;
  }

  public UUID getLotId() {
    return lotId;
  }

  public String getLotNumber() {
    return lotNumber;
  }

  public Instant getApplicationDate() {
    return applicationDate;
  }

  public UUID getDoseOptionId() {
    return doseOptionId;
  }

  public UUID getPneumococcalTypeOptionId() {
    return pneumococcalTypeOptionId;
  }

  public String getVaccineNameSnapshot() {
    return vaccineNameSnapshot;
  }

  public String getVaccineCodeSnapshot() {
    return vaccineCodeSnapshot;
  }

  public String getDoseLabelSnapshot() {
    return doseLabelSnapshot;
  }

  public String getDoseValueSnapshot() {
    return doseValueSnapshot;
  }

  public String getPneumococcalTypeSnapshot() {
    return pneumococcalTypeSnapshot;
  }

  public long getCatalogVersion() {
    return catalogVersion;
  }

  public UUID getSelectedLaboratoryId() {
    return selectedLaboratoryId;
  }

  public String getSelectedLaboratorySnapshot() {
    return selectedLaboratorySnapshot;
  }

  public UUID getSelectedSyringeId() {
    return selectedSyringeId;
  }

  public String getSelectedSyringeSnapshot() {
    return selectedSyringeSnapshot;
  }

  public UUID getSelectedDropperId() {
    return selectedDropperId;
  }

  public String getSelectedDropperSnapshot() {
    return selectedDropperSnapshot;
  }

  public UUID getSelectedObservationId() {
    return selectedObservationId;
  }

  public String getSelectedObservationSnapshot() {
    return selectedObservationSnapshot;
  }

  public Status getStatus() {
    return status;
  }

  public String getCancelledReason() {
    return cancelledReason;
  }

  public UUID getCancelledBy() {
    return cancelledBy;
  }

  public Instant getCancelledAt() {
    return cancelledAt;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }
}
