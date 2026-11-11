package com.pai.api.inventory.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.UUID;
import org.junit.jupiter.api.Test;

class VialTransferTest {
  private final UUID id = UUID.randomUUID();
  private final UUID institution = UUID.randomUUID();
  private final UUID lot = UUID.randomUUID();
  private final UUID vaccinator = UUID.randomUUID();

  @Test
  void dispatchReservesWholeVialsWithoutRequiringCampaign() {
    var result = VialTransfer.dispatch(id, institution, lot, vaccinator, null, 10, 4);
    assertThat(result.remainingVials()).isEqualTo(6);
    assertThat(result.assignment().vials()).isEqualTo(4);
    assertThat(result.assignment().campaignId()).isNull();
    assertThat(result.assignment().status()).isEqualTo(VialTransfer.Status.IN_TRANSIT);
  }

  @Test
  void dispatchRetainsOptionalCampaign() {
    UUID campaign = UUID.randomUUID();
    var result = VialTransfer.dispatch(id, institution, lot, vaccinator, campaign, 1, 1);
    assertThat(result.remainingVials()).isZero();
    assertThat(result.assignment().campaignId()).isEqualTo(campaign);
  }

  @Test
  void dispatchRejectsInvalidQuantitiesAndInsufficientStock() {
    assertThatThrownBy(() -> VialTransfer.dispatch(id, institution, lot, vaccinator, null, -1, 1))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> VialTransfer.dispatch(id, institution, lot, vaccinator, null, 1, 0))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> VialTransfer.dispatch(id, institution, lot, vaccinator, null, 1, -1))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> VialTransfer.dispatch(id, institution, lot, vaccinator, null, 1, 2))
        .isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  void onlyAssignedVaccinatorCanReceiveExactlyOnceAndInFull() {
    var sent = VialTransfer.dispatch(id, institution, lot, vaccinator, null, 5, 3).assignment();
    assertThatThrownBy(() -> VialTransfer.receive(sent, UUID.randomUUID(), 3))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> VialTransfer.receive(sent, vaccinator, 2))
        .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("incidencia");
    assertThatThrownBy(() -> VialTransfer.receive(sent, vaccinator, 4))
        .isInstanceOf(IllegalArgumentException.class).hasMessageContaining("incidencia");
    var received = VialTransfer.receive(sent, vaccinator, 3);
    assertThat(received.status()).isEqualTo(VialTransfer.Status.RECEIVED);
    assertThatThrownBy(() -> VialTransfer.receive(received, vaccinator, 3))
        .isInstanceOf(IllegalStateException.class);
  }
}
