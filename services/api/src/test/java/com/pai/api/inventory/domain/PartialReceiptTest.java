package com.pai.api.inventory.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class PartialReceiptTest {
  @Test
  void partialReceiptLeavesUnexplainedVialsOutsideCustody() {
    var balance = PartialReceipt.first(10, 8, "Entrega incompleta");
    assertThat(balance.received()).isEqualTo(8);
    assertThat(balance.pendingDifference()).isEqualTo(2);
    assertThat(PartialReceipt.complementary(balance, 2))
        .isEqualTo(new PartialReceipt.Balance(10, 10, 0));
  }

  @Test
  void rejectsMissingExplanationInvalidCountsAndOverReceipt() {
    assertThatThrownBy(() -> PartialReceipt.first(10, 8, " "))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> PartialReceipt.first(10, 11, "Error"))
        .isInstanceOf(IllegalArgumentException.class);
    var balance = PartialReceipt.first(10, 8, "Faltante");
    assertThatThrownBy(() -> PartialReceipt.complementary(balance, 3))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> new PartialReceipt.Balance(10, 8, 1))
        .isInstanceOf(IllegalArgumentException.class);
  }
}
