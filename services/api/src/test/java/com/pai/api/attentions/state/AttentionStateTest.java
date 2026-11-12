package com.pai.api.attentions.state;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.pai.api.attentions.entity.AttentionEntity;
import com.pai.api.attentions.exception.InvalidClinicalStateException;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

@DisplayName("Patron GoF State - Ciclo de Vida de Atenciones Clinicas")
class AttentionStateTest {

  private AttentionEntity attention;
  private Instant now;

  @BeforeEach
  void setUp() {
    now = Instant.now();
    attention = new AttentionEntity(
        UUID.randomUUID(),
        UUID.randomUUID(),
        UUID.randomUUID(),
        UUID.randomUUID(),
        now,
        1L,
        null,
        now);
  }

  @Nested
  @DisplayName("Estado DRAFT")
  class DraftStateTests {

    @Test
    @DisplayName("Inicia en DRAFT con comportamiento editable y aceptando dosis")
    void initialStateIsDraft() {
      assertThat(attention.getStatus()).isEqualTo(AttentionEntity.Status.DRAFT);
      assertThat(attention.isEditable()).isTrue();
      assertThat(attention.acceptsDoses()).isTrue();
      assertThat(attention.getState()).isSameAs(DraftState.INSTANCE);
    }

    @Test
    @DisplayName("Registrar primera dosis transiciona automaticamente a IN_PROGRESS")
    void prepareForDoseTransitionsToInProgress() {
      attention.prepareForDose(now);

      assertThat(attention.getStatus()).isEqualTo(AttentionEntity.Status.IN_PROGRESS);
      assertThat(attention.getState()).isSameAs(InProgressState.INSTANCE);
      assertThat(attention.isEditable()).isTrue();
      assertThat(attention.acceptsDoses()).isTrue();
    }

    @Test
    @DisplayName("Permite actualizar datos clinicos")
    void permitsUpdate() {
      attention.validateCanUpdate();
      // No lanza excepcion
    }

    @Test
    @DisplayName("Permite completar directamente transicionando a COMPLETED")
    void permitsComplete() {
      attention.complete(now);

      assertThat(attention.getStatus()).isEqualTo(AttentionEntity.Status.COMPLETED);
      assertThat(attention.getState()).isSameAs(CompletedState.INSTANCE);
      assertThat(attention.isEditable()).isFalse();
      assertThat(attention.acceptsDoses()).isFalse();
    }

    @Test
    @DisplayName("Permite anular directamente transicionando a CANCELLED")
    void permitsCancel() {
      attention.cancel(now);

      assertThat(attention.getStatus()).isEqualTo(AttentionEntity.Status.CANCELLED);
      assertThat(attention.getState()).isSameAs(CancelledState.INSTANCE);
      assertThat(attention.isEditable()).isFalse();
    }
  }

  @Nested
  @DisplayName("Estado IN_PROGRESS")
  class InProgressStateTests {

    @BeforeEach
    void advanceToInProgress() {
      attention.prepareForDose(now);
      assertThat(attention.getStatus()).isEqualTo(AttentionEntity.Status.IN_PROGRESS);
    }

    @Test
    @DisplayName("Dosis adicionales se aceptan manteniendose en IN_PROGRESS")
    void permitsAdditionalDosesWithoutChangingState() {
      attention.prepareForDose(now);

      assertThat(attention.getStatus()).isEqualTo(AttentionEntity.Status.IN_PROGRESS);
      assertThat(attention.getState()).isSameAs(InProgressState.INSTANCE);
    }

    @Test
    @DisplayName("Permite completar transicionando a COMPLETED")
    void permitsComplete() {
      attention.complete(now);

      assertThat(attention.getStatus()).isEqualTo(AttentionEntity.Status.COMPLETED);
      assertThat(attention.getState()).isSameAs(CompletedState.INSTANCE);
    }

    @Test
    @DisplayName("Permite anular con motivo transicionando a CANCELLED")
    void permitsCancel() {
      attention.cancel(now);

      assertThat(attention.getStatus()).isEqualTo(AttentionEntity.Status.CANCELLED);
      assertThat(attention.getState()).isSameAs(CancelledState.INSTANCE);
    }
  }

  @Nested
  @DisplayName("Estado COMPLETED (Terminal / Sellado)")
  class CompletedStateTests {

    @BeforeEach
    void completeAttention() {
      attention.complete(now);
      assertThat(attention.getStatus()).isEqualTo(AttentionEntity.Status.COMPLETED);
    }

    @Test
    @DisplayName("Rechaza registrar dosis lanzando InvalidClinicalStateException")
    void rejectsDoses() {
      assertThatThrownBy(() -> attention.prepareForDose(now))
          .isInstanceOf(InvalidClinicalStateException.class)
          .hasMessageContaining("No se pueden registrar dosis en una atencion completada o anulada.");
    }

    @Test
    @DisplayName("Rechaza modificaciones de datos generales")
    void rejectsUpdate() {
      assertThatThrownBy(() -> attention.validateCanUpdate())
          .isInstanceOf(InvalidClinicalStateException.class)
          .hasMessageContaining("La atencion no se puede modificar en su estado actual (COMPLETED).");
    }

    @Test
    @DisplayName("Rechaza completar nuevamente")
    void rejectsCompleteAgain() {
      assertThatThrownBy(() -> attention.complete(now))
          .isInstanceOf(InvalidClinicalStateException.class)
          .hasMessageContaining("La atencion no se puede modificar en su estado actual (COMPLETED).");
    }

    @Test
    @DisplayName("Permite anulacion justificada institucional transicionando a CANCELLED")
    void permitsJustifiedCancellation() {
      attention.cancel(now);

      assertThat(attention.getStatus()).isEqualTo(AttentionEntity.Status.CANCELLED);
      assertThat(attention.getState()).isSameAs(CancelledState.INSTANCE);
    }
  }

  @Nested
  @DisplayName("Estado CANCELLED (Terminal / Anulado)")
  class CancelledStateTests {

    @BeforeEach
    void cancelAttention() {
      attention.cancel(now);
      assertThat(attention.getStatus()).isEqualTo(AttentionEntity.Status.CANCELLED);
    }

    @Test
    @DisplayName("Rechaza registrar dosis")
    void rejectsDoses() {
      assertThatThrownBy(() -> attention.prepareForDose(now))
          .isInstanceOf(InvalidClinicalStateException.class)
          .hasMessageContaining("No se pueden registrar dosis en una atencion completada o anulada.");
    }

    @Test
    @DisplayName("Rechaza modificaciones generales")
    void rejectsUpdate() {
      assertThatThrownBy(() -> attention.validateCanUpdate())
          .isInstanceOf(InvalidClinicalStateException.class)
          .hasMessageContaining("La atencion no se puede modificar en su estado actual (CANCELLED).");
    }

    @Test
    @DisplayName("Rechaza completar una atencion ya anulada")
    void rejectsComplete() {
      assertThatThrownBy(() -> attention.complete(now))
          .isInstanceOf(InvalidClinicalStateException.class)
          .hasMessageContaining("No se puede completar una atencion anulada.");
    }

    @Test
    @DisplayName("Rechaza anular nuevamente indicando que ya esta anulada")
    void rejectsCancelAgain() {
      assertThatThrownBy(() -> attention.cancel(now))
          .isInstanceOf(InvalidClinicalStateException.class)
          .hasMessageContaining("La atencion ya esta anulada.");
    }
  }

  @Nested
  @DisplayName("Mapeo de Status a AttentionState")
  class StatusToStateTests {

    @Test
    @DisplayName("Cada constante del enum vincula su ConcreteState singleton")
    void mapsAllEnumsToSingletons() {
      assertThat(AttentionEntity.Status.DRAFT.toState()).isSameAs(DraftState.INSTANCE);
      assertThat(AttentionEntity.Status.IN_PROGRESS.toState()).isSameAs(InProgressState.INSTANCE);
      assertThat(AttentionEntity.Status.COMPLETED.toState()).isSameAs(CompletedState.INSTANCE);
      assertThat(AttentionEntity.Status.CANCELLED.toState()).isSameAs(CancelledState.INSTANCE);
    }
  }
}

