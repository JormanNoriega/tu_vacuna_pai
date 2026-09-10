package com.pai.api.attentions.entity;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

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

    public enum Status { REGISTERED, CANCELLED }

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

    protected AppliedDoseEntity() {
    }

    public AppliedDoseEntity(UUID id, UUID attentionId, UUID vaccineId, UUID lotId,
            String lotNumber, Instant applicationDate, UUID doseOptionId,
            UUID pneumococcalTypeOptionId, String vaccineNameSnapshot,
            String vaccineCodeSnapshot, String doseLabelSnapshot, String doseValueSnapshot,
            String pneumococcalTypeSnapshot, long catalogVersion,
            UUID selectedLaboratoryId, String selectedLaboratorySnapshot,
            UUID selectedSyringeId, String selectedSyringeSnapshot,
            UUID selectedDropperId, String selectedDropperSnapshot,
            UUID selectedObservationId, String selectedObservationSnapshot, Instant now) {
        this.id = id;
        this.attentionId = attentionId;
        this.vaccineId = vaccineId;
        this.lotId = lotId;
        this.lotNumber = lotNumber;
        this.applicationDate = applicationDate;
        this.doseOptionId = doseOptionId;
        this.pneumococcalTypeOptionId = pneumococcalTypeOptionId;
        this.vaccineNameSnapshot = vaccineNameSnapshot;
        this.vaccineCodeSnapshot = vaccineCodeSnapshot;
        this.doseLabelSnapshot = doseLabelSnapshot;
        this.doseValueSnapshot = doseValueSnapshot;
        this.pneumococcalTypeSnapshot = pneumococcalTypeSnapshot;
        this.catalogVersion = catalogVersion;
        this.selectedLaboratoryId = selectedLaboratoryId;
        this.selectedLaboratorySnapshot = selectedLaboratorySnapshot;
        this.selectedSyringeId = selectedSyringeId;
        this.selectedSyringeSnapshot = selectedSyringeSnapshot;
        this.selectedDropperId = selectedDropperId;
        this.selectedDropperSnapshot = selectedDropperSnapshot;
        this.selectedObservationId = selectedObservationId;
        this.selectedObservationSnapshot = selectedObservationSnapshot;
        this.status = Status.REGISTERED;
        this.createdAt = now;
    }

    public void cancel(String reason, UUID actorId, Instant now) {
        this.status = Status.CANCELLED;
        this.cancelledReason = reason;
        this.cancelledBy = actorId;
        this.cancelledAt = now;
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
