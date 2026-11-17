package com.pai.api.inventory.domain;

import static org.assertj.core.api.Assertions.assertThat;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class HistoricalCustodyTransitionTest {
  private final UUID assignment = UUID.randomUUID(), lot = UUID.randomUUID();

  @Test
  void retainsEventsAtAssignmentLevelWithoutAllocatingBetweenReceipts() {
    var first = new HistoricalCustodyTransition.Receipt(UUID.randomUUID(), assignment, lot, 8);
    var second = new HistoricalCustodyTransition.Receipt(UUID.randomUUID(), assignment, lot, 2);
    var event = new HistoricalCustodyTransition.Event(UUID.randomUUID(), assignment, lot, "RETURN_PENDING", 3);
    var result = HistoricalCustodyTransition.inspect(assignment, lot, 10, false, List.of(first, second), List.of(event));
    assertThat(result.reasons()).isEmpty();
    assertThat(result.receipts()).containsExactly(first, second);
    assertThat(result.events()).containsExactly(event);
    assertThat(result.recordedUnaccounted()).hasValue(7);
  }

  @Test
  void historicalFullReceiptUsesAssignmentEvidenceWithoutInventingReceipt() {
    var event = new HistoricalCustodyTransition.Event(UUID.randomUUID(), assignment, lot, "RETURN_AVAILABLE", 3);
    var result = HistoricalCustodyTransition.inspect(assignment, lot, 8, true, List.of(), List.of(event));
    assertThat(result.reasons()).isEmpty();
    assertThat(result.receipts()).isEmpty();
    assertThat(result.recordedUnaccounted()).hasValue(5);
  }

  @Test
  void incompatibleOrDuplicateEvidenceMustBeReviewedAndDoesNotProduceAValue() {
    var receipt = new HistoricalCustodyTransition.Receipt(UUID.randomUUID(), assignment, lot, 4);
    var event = new HistoricalCustodyTransition.Event(UUID.randomUUID(), assignment, lot, "INCIDENT_LOST", 5);
    var result = HistoricalCustodyTransition.inspect(assignment, lot, 4, false,
        List.of(receipt, receipt), List.of(event, event));
    assertThat(result.reasons()).contains("DUPLICATE_RECEIPT", "DUPLICATE_EVENT",
        "RECEIPT_TOTAL_MISMATCH", "EVENTS_EXCEED_RECEIVED");
    assertThat(result.recordedUnaccounted()).isEmpty();
  }

  @Test
  void mixedSourcesUnknownStatusAndWrongScopeRequireReview() {
    var receipt = new HistoricalCustodyTransition.Receipt(UUID.randomUUID(), assignment, lot, 4);
    var event = new HistoricalCustodyTransition.Event(UUID.randomUUID(), UUID.randomUUID(), lot, "UNKNOWN", 1);
    var result = HistoricalCustodyTransition.inspect(assignment, lot, 4, true, List.of(receipt), List.of(event));
    assertThat(result.reasons()).contains("MIXED_RECEIPT_EVIDENCE", "EVENT_SCOPE_MISMATCH", "UNKNOWN_EVENT_STATUS");
    assertThat(result.recordedUnaccounted()).isEmpty();
  }

  @Test
  void zeroInitialReceiptRemainsEvidenceWithoutAddingCustody() {
    var zero = new HistoricalCustodyTransition.Receipt(UUID.randomUUID(), assignment, lot, 0);
    var result = HistoricalCustodyTransition.inspect(assignment, lot, 0, false, List.of(zero), List.of());
    assertThat(result.reasons()).isEmpty();
    assertThat(result.recordedUnaccounted()).hasValue(0);
  }
}
