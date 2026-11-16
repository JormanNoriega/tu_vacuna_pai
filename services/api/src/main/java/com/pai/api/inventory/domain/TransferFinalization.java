package com.pai.api.inventory.domain;

/**
 * Evaluacion aislada de la transferencia; no cierra custodias ni modifica saldos.
 * No representa todavia un estado persistido ni autoriza operaciones offline.
 */
public final class TransferFinalization {
  private TransferFinalization() {}

  public enum Outcome {
    AUTOMATIC_FINALIZATION,
    ADMINISTRATOR_REVIEW,
    TRANSFER_PENDING
  }

  /**
   * Las cantidades resueltas no se consideran recibidas. La verificacion fisica
   * pendiente tras una correccion se sigue por separado y no acredita deposito.
   * hadTransferIncident incluye diferencias historicas ya resueltas, tambien
   * cuando se completaron mediante una recepcion complementaria.
   */
  public static Outcome evaluate(int dispatched, int received, int resolved,
      boolean receiptConfirmed, boolean hadTransferIncident, boolean physicalFollowUpPending) {
    if (dispatched <= 0 || received < 0 || resolved < 0
        || (long) received + resolved > dispatched
        || (!receiptConfirmed && (received != 0 || resolved != 0))) {
      throw new IllegalArgumentException("Las cantidades de transferencia no son coherentes.");
    }
    if (!receiptConfirmed || received + resolved < dispatched) return Outcome.TRANSFER_PENDING;
    if (resolved > 0 || hadTransferIncident || physicalFollowUpPending) return Outcome.ADMINISTRATOR_REVIEW;
    return Outcome.AUTOMATIC_FINALIZATION;
  }
}
