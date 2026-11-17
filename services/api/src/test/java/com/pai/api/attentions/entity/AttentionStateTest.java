package com.pai.api.attentions.entity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.pai.api.attentions.exception.InvalidClinicalStateException;
import com.pai.api.attentions.state.AttentionState;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class AttentionStateTest {
  private final AttentionStateConverter converter = new AttentionStateConverter();

  @ParameterizedTest
  @CsvSource({
      "DRAFT, true, COMPLETED, CANCELLED",
      "IN_PROGRESS, true, COMPLETED, CANCELLED",
      "COMPLETED, false, REJECTED, CANCELLED",
      "CANCELLED, false, REJECTED, REJECTED"
  })
  void statesEnforceTransitionMatrix(String code, boolean editable, String completion, String cancellation) {
    AttentionState state = converter.convertToEntityAttribute(code);
    assertThat(converter.convertToDatabaseColumn(state)).isEqualTo(code);
    assertThat(state.isEditable()).isEqualTo(editable);
    assertThat(state.acceptsDoses()).isEqualTo(editable);
    if ("REJECTED".equals(completion)) {
      assertThatThrownBy(state::complete).isInstanceOf(InvalidClinicalStateException.class);
    } else {
      assertThat(state.complete().code()).isEqualTo(completion);
    }
    if ("REJECTED".equals(cancellation)) {
      assertThatThrownBy(state::cancel).isInstanceOf(InvalidClinicalStateException.class);
    } else {
      assertThat(state.cancel().code()).isEqualTo(cancellation);
    }
  }

  @Test
  void invalidPersistedStateFailsExplicitly() {
    assertThatThrownBy(() -> converter.convertToEntityAttribute(null))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> converter.convertToEntityAttribute("UNKNOWN"))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> converter.convertToDatabaseColumn(null))
        .isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  void entityKeepsStateAndTimestampWhenTransitionOrEditIsRejected() {
    Instant initial = Instant.parse("2026-01-01T00:00:00Z");
    Instant completed = initial.plusSeconds(1);
    AttentionEntity attention = new AttentionEntity(UUID.randomUUID(), UUID.randomUUID(),
        UUID.randomUUID(), UUID.randomUUID(), initial, 1L, null, initial);
    attention.complete(completed);
    assertThatThrownBy(() -> attention.complete(initial.plusSeconds(2)))
        .isInstanceOf(InvalidClinicalStateException.class);
    assertThatThrownBy(() -> attention.updateDetails(initial, "cambio", initial.plusSeconds(2)))
        .isInstanceOf(InvalidClinicalStateException.class);
    assertThatThrownBy(() -> attention.setLocation(1.0, 2.0))
        .isInstanceOf(InvalidClinicalStateException.class);
    assertThat(attention.getStatus().code()).isEqualTo("COMPLETED");
    assertThat(attention.getUpdatedAt()).isEqualTo(completed);
    attention.cancel(initial.plusSeconds(3));
    assertThat(attention.getStatus().code()).isEqualTo("CANCELLED");
  }
}
