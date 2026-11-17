package com.pai.api.inventory.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static com.pai.api.inventory.domain.TransferFinalization.Outcome.*;

import org.junit.jupiter.api.Test;

class TransferFinalizationTest {
  @Test
  void completeReceiptWithoutIncidentsCanFinalizeAutomatically() {
    assertThat(TransferFinalization.evaluate(10, 10, 0, true, false, false))
        .isEqualTo(AUTOMATIC_FINALIZATION);
  }

  @Test
  void pendingDifferenceOrUnconfirmedReceiptCannotFinalize() {
    assertThat(TransferFinalization.evaluate(10, 0, 0, false, false, false)).isEqualTo(TRANSFER_PENDING);
    assertThat(TransferFinalization.evaluate(10, 8, 0, true, true, false)).isEqualTo(TRANSFER_PENDING);
    assertThat(TransferFinalization.evaluate(10, 0, 0, true, true, false)).isEqualTo(TRANSFER_PENDING);
  }

  @Test
  void resolutionsAndIncidentsRequireAdministratorEvenWithPhysicalFollowUp() {
    assertThat(TransferFinalization.evaluate(10, 8, 2, true, true, true)).isEqualTo(ADMINISTRATOR_REVIEW);
    assertThat(TransferFinalization.evaluate(10, 8, 2, true, false, false)).isEqualTo(ADMINISTRATOR_REVIEW);
    assertThat(TransferFinalization.evaluate(10, 10, 0, true, true, false)).isEqualTo(ADMINISTRATOR_REVIEW);
    assertThat(TransferFinalization.evaluate(10, 10, 0, true, false, true)).isEqualTo(ADMINISTRATOR_REVIEW);
  }

  @Test
  void invalidAmountsAndUnconfirmedTransfersCannotImplyCustody() {
    assertThatThrownBy(() -> TransferFinalization.evaluate(10, 8, 3, true, false, false))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> TransferFinalization.evaluate(10, 1, 0, false, false, false))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> TransferFinalization.evaluate(0, 0, 0, true, false, false))
        .isInstanceOf(IllegalArgumentException.class);
  }
}
