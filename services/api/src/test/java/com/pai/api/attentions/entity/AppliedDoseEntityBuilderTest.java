package com.pai.api.attentions.entity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Verifica que el Builder de {@link AppliedDoseEntity} centraliza las
 * invariantes del agregado (valores por defecto + campos requeridos). */
class AppliedDoseEntityBuilderTest {

  private static final UUID ATTENTION_ID = UUID.randomUUID();

  private AppliedDoseEntity.Builder base() {
    return AppliedDoseEntity.builder()
        .attentionId(ATTENTION_ID)
        .vaccine(UUID.randomUUID(), "Influenza", "INF", 3L)
        .dose(UUID.randomUUID(), "Primera dosis", "1");
  }

  @Test
  void build_generatesIdStatusAndTimestamps() {
    AppliedDoseEntity dose = base().build();

    assertThat(dose.getId()).isNotNull();
    assertThat(dose.getStatus()).isEqualTo(AppliedDoseEntity.Status.REGISTERED);
    assertThat(dose.getCreatedAt()).isNotNull();
    assertThat(dose.getApplicationDate()).isNotNull();
    assertThat(dose.getCancelledReason()).isNull();
    assertThat(dose.getCancelledBy()).isNull();
    assertThat(dose.getCancelledAt()).isNull();
  }

  @Test
  void build_usesProvidedIdAndApplicationDate() {
    UUID id = UUID.randomUUID();
    Instant appliedAt = Instant.parse("2026-03-01T10:00:00Z");

    AppliedDoseEntity dose = base().id(id).applicationDate(appliedAt).build();

    assertThat(dose.getId()).isEqualTo(id);
    assertThat(dose.getApplicationDate()).isEqualTo(appliedAt);
  }

  @Test
  void build_setsSnapshotAndOperationalFields() {
    UUID labId = UUID.randomUUID();

    AppliedDoseEntity dose =
        base().pneumococcal(UUID.randomUUID(), "PCV13")
            .laboratory(labId, "Pfizer")
            .syringe(UUID.randomUUID(), "23G")
            .dropper(null, null)
            .observation(UUID.randomUUID(), "Sin novedad")
            .operational("LOT-J-1", "DIL-1", 2, "observacion libre")
            .build();

    assertThat(dose.getVaccineNameSnapshot()).isEqualTo("Influenza");
    assertThat(dose.getVaccineCodeSnapshot()).isEqualTo("INF");
    assertThat(dose.getCatalogVersion()).isEqualTo(3L);
    assertThat(dose.getDoseLabelSnapshot()).isEqualTo("Primera dosis");
    assertThat(dose.getDoseValueSnapshot()).isEqualTo("1");
    assertThat(dose.getPneumococcalTypeSnapshot()).isEqualTo("PCV13");
    assertThat(dose.getSelectedLaboratoryId()).isEqualTo(labId);
    assertThat(dose.getSelectedLaboratorySnapshot()).isEqualTo("Pfizer");
    assertThat(dose.getSyringeLot()).isEqualTo("LOT-J-1");
    assertThat(dose.getDiluent()).isEqualTo("DIL-1");
    assertThat(dose.getVialCount()).isEqualTo(2);
    assertThat(dose.getCustomObservation()).isEqualTo("observacion libre");
  }

  @Test
  void build_rejectsMissingAttentionId() {
    assertThatThrownBy(
            () ->
                AppliedDoseEntity.builder()
                    .vaccine(UUID.randomUUID(), "Influenza", "INF", 1L)
                    .dose(UUID.randomUUID(), "1", "1")
                    .build())
        .isInstanceOf(IllegalStateException.class)
        .hasMessageContaining("attentionId");
  }

  @Test
  void build_rejectsMissingVaccine() {
    assertThatThrownBy(
            () ->
                AppliedDoseEntity.builder()
                    .attentionId(ATTENTION_ID)
                    .dose(UUID.randomUUID(), "1", "1")
                    .build())
        .isInstanceOf(IllegalStateException.class)
        .hasMessageContaining("vaccineId");
  }

  @Test
  void build_rejectsMissingDoseLabel() {
    assertThatThrownBy(
            () ->
                AppliedDoseEntity.builder()
                    .attentionId(ATTENTION_ID)
                    .vaccine(UUID.randomUUID(), "Influenza", "INF", 1L)
                    .dose(UUID.randomUUID(), null, "1")
                    .build())
        .isInstanceOf(IllegalStateException.class)
        .hasMessageContaining("doseLabelSnapshot");
  }

  @Test
  void cancel_marksDoseCancelledWithAudit() {
    AppliedDoseEntity dose = base().build();
    UUID actor = UUID.randomUUID();
    Instant when = Instant.now();

    dose.cancel("dato duplicado", actor, when);

    assertThat(dose.getStatus()).isEqualTo(AppliedDoseEntity.Status.CANCELLED);
    assertThat(dose.getCancelledReason()).isEqualTo("dato duplicado");
    assertThat(dose.getCancelledBy()).isEqualTo(actor);
    assertThat(dose.getCancelledAt()).isEqualTo(when);
  }
}
