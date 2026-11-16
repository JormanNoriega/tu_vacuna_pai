package com.pai.api.inventory.domain;

/**
 * Calculo de cantidades para una recepcion parcial de frascos cerrados.
 * No persiste, no resuelve diferencias y no modifica saldos por si mismo.
 */
public final class PartialReceipt {
  private PartialReceipt() {}

  public record Balance(int dispatched, int received, int pendingDifference) {
    public Balance {
      if (dispatched <= 0 || received < 0 || pendingDifference < 0
          || (long) received + pendingDifference != dispatched) {
        throw new IllegalArgumentException("Las cantidades de la entrega no son coherentes.");
      }
    }
  }

  /** La primera confirmacion exige explicar cualquier diferencia. */
  public static Balance first(int dispatched, int accepted, String differenceNote) {
    if (dispatched <= 0 || accepted < 0 || accepted > dispatched) {
      throw new IllegalArgumentException("La cantidad recibida no es valida.");
    }
    if (accepted < dispatched && (differenceNote == null || differenceNote.isBlank())) {
      throw new IllegalArgumentException("Describe la diferencia de recepcion.");
    }
    return new Balance(dispatched, accepted, dispatched - accepted);
  }

  /** Agrega solamente frascos efectivamente recibidos de la diferencia pendiente. */
  public static Balance complementary(Balance balance, int accepted) {
    if (balance == null || accepted <= 0 || accepted > balance.pendingDifference()) {
      throw new IllegalArgumentException("La cantidad supera la diferencia pendiente.");
    }
    return new Balance(balance.dispatched(), balance.received() + accepted,
        balance.pendingDifference() - accepted);
  }
}
