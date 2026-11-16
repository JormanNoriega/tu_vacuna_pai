package com.pai.api.inventory.domain;

import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.OptionalLong;
import java.util.Set;
import java.util.UUID;

/**
 * Analisis previo, por entrega, de evidencia historica. No asigna eventos a
 * recepciones, no persiste, no acredita stock y no verifica el origen de datos.
 */
public final class HistoricalCustodyTransition {
  private HistoricalCustodyTransition() {}

  private static final Set<String> KNOWN_EVENTS = Set.of(
      "RETURN_PENDING", "RETURN_AVAILABLE", "RETURN_QUARANTINED",
      "INCIDENT_LOST", "INCIDENT_QUARANTINED");

  public record Receipt(UUID id, UUID assignmentId, UUID lotId, int vials) {
    public Receipt {
      Objects.requireNonNull(id, "id");
      Objects.requireNonNull(assignmentId, "assignmentId");
      Objects.requireNonNull(lotId, "lotId");
      if (vials < 0) throw new IllegalArgumentException("Recepcion negativa.");
    }
  }

  public record Event(UUID id, UUID assignmentId, UUID lotId, String status, int vials) {
    public Event {
      Objects.requireNonNull(id, "id");
      Objects.requireNonNull(assignmentId, "assignmentId");
      Objects.requireNonNull(lotId, "lotId");
      Objects.requireNonNull(status, "status");
      if (vials <= 0) throw new IllegalArgumentException("Novedad sin cantidad positiva.");
    }
  }

  /** La ausencia de cifra significa revision necesaria, no saldo cero. */
  public record Review(UUID assignmentId, UUID lotId, List<Receipt> receipts, List<Event> events,
      boolean legacyReceivedAssignment, Set<String> reasons, OptionalLong recordedUnaccounted) {
    public Review {
      receipts = List.copyOf(receipts);
      events = List.copyOf(events);
      reasons = Set.copyOf(reasons);
      Objects.requireNonNull(recordedUnaccounted, "recordedUnaccounted");
    }
  }

  /**
   * legacyReceivedAssignment solo procede de una entrega historica recibida
   * sin registros de recepcion; no autoriza inventar una recepcion.
   */
  public static Review inspect(UUID assignmentId, UUID lotId, int recordedReceived,
      boolean legacyReceivedAssignment, List<Receipt> receipts, List<Event> events) {
    Objects.requireNonNull(assignmentId, "assignmentId");
    Objects.requireNonNull(lotId, "lotId");
    if (recordedReceived < 0) throw new IllegalArgumentException("Recepcion negativa.");
    var receiptCopy = List.copyOf(receipts);
    var eventCopy = List.copyOf(events);
    var reasons = new HashSet<String>();
    var receiptIds = new HashSet<UUID>();
    var eventIds = new HashSet<UUID>();
    long receiptsTotal = 0, eventsTotal = 0;
    for (var receipt : receiptCopy) {
      if (!receiptIds.add(receipt.id())) reasons.add("DUPLICATE_RECEIPT");
      if (!assignmentId.equals(receipt.assignmentId()) || !lotId.equals(receipt.lotId()))
        reasons.add("RECEIPT_SCOPE_MISMATCH");
      receiptsTotal = Math.addExact(receiptsTotal, receipt.vials());
    }
    for (var event : eventCopy) {
      if (!eventIds.add(event.id())) reasons.add("DUPLICATE_EVENT");
      if (!assignmentId.equals(event.assignmentId()) || !lotId.equals(event.lotId()))
        reasons.add("EVENT_SCOPE_MISMATCH");
      if (!KNOWN_EVENTS.contains(event.status())) reasons.add("UNKNOWN_EVENT_STATUS");
      eventsTotal = Math.addExact(eventsTotal, event.vials());
    }
    if (legacyReceivedAssignment && !receiptCopy.isEmpty()) reasons.add("MIXED_RECEIPT_EVIDENCE");
    if (legacyReceivedAssignment && recordedReceived == 0) reasons.add("INVALID_LEGACY_EVIDENCE");
    if (!legacyReceivedAssignment && receiptsTotal != recordedReceived) reasons.add("RECEIPT_TOTAL_MISMATCH");
    if (eventsTotal > recordedReceived) reasons.add("EVENTS_EXCEED_RECEIVED");
    return new Review(assignmentId, lotId, receiptCopy, eventCopy, legacyReceivedAssignment,
        reasons, reasons.isEmpty() ? OptionalLong.of(recordedReceived - eventsTotal) : OptionalLong.empty());
  }
}
