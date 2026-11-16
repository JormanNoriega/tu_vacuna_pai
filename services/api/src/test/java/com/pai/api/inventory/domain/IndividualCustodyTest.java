package com.pai.api.inventory.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class IndividualCustodyTest {
  private final UUID institution = UUID.randomUUID(), custodian = UUID.randomUUID(), lot = UUID.randomUUID();
  private final UUID firstAssignment = UUID.randomUUID(), secondAssignment = UUID.randomUUID();

  private IndividualCustody.Contribution receipt(UUID assignment, int received, int removed) {
    return new IndividualCustody.Contribution(
        new IndividualCustody.Source(IndividualCustody.SourceType.RECEIPT, UUID.randomUUID()),
        assignment, lot, received, removed);
  }

  @Test
  void combinesConfirmedSourcesWithoutLosingTheirAssignments() {
    var first = receipt(firstAssignment, 8, 3);
    var complementary = receipt(firstAssignment, 2, 0);
    var second = receipt(secondAssignment, 5, 1);
    var sources = new ArrayList<>(List.of(first, complementary, second));
    var view = IndividualCustody.project(institution, custodian, lot, sources);
    sources.clear();
    assertThat(view.received()).isEqualTo(15);
    assertThat(view.removed()).isEqualTo(4);
    assertThat(view.unaccounted()).isEqualTo(11);
    assertThat(view.contributions()).containsExactly(first, complementary, second);
  }

  @Test
  void historicalAssignmentRemainsExplicitRatherThanInventingAReceipt() {
    var source = new IndividualCustody.Source(IndividualCustody.SourceType.LEGACY_ASSIGNMENT, firstAssignment);
    var historical = new IndividualCustody.Contribution(source, firstAssignment, lot, 4, 1);
    var view = IndividualCustody.project(institution, custodian, lot, List.of(historical));
    assertThat(view.contributions().getFirst().source()).isEqualTo(source);
    assertThat(view.unaccounted()).isEqualTo(3);
  }

  @Test
  void rejectsDuplicateSourcesDifferentLotsAndNegativeAmounts() {
    var first = receipt(firstAssignment, 8, 0);
    assertThatThrownBy(() -> IndividualCustody.project(institution, custodian, lot, List.of(first, first)))
        .isInstanceOf(IllegalArgumentException.class);
    var otherLot = new IndividualCustody.Contribution(first.source(), firstAssignment, UUID.randomUUID(), 2, 0);
    assertThatThrownBy(() -> IndividualCustody.project(institution, custodian, lot, List.of(otherLot)))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> new IndividualCustody.Contribution(first.source(), firstAssignment, lot, 2, 3))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> new IndividualCustody.Contribution(
        new IndividualCustody.Source(IndividualCustody.SourceType.LEGACY_ASSIGNMENT, UUID.randomUUID()),
        firstAssignment, lot, 1, 0)).isInstanceOf(IllegalArgumentException.class);
    var legacy = new IndividualCustody.Contribution(
        new IndividualCustody.Source(IndividualCustody.SourceType.LEGACY_ASSIGNMENT, firstAssignment),
        firstAssignment, lot, 8, 0);
    assertThatThrownBy(() -> IndividualCustody.project(institution, custodian, lot, List.of(legacy, first)))
        .isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  void totalsCannotBeSuppliedIndependentlyOfEvidence() {
    var contribution = receipt(firstAssignment, 3, 0);
    assertThatThrownBy(() -> new IndividualCustody.Projection(institution, custodian, lot,
        List.of(contribution), 10, 0, 10)).isInstanceOf(IllegalArgumentException.class);
  }
}
