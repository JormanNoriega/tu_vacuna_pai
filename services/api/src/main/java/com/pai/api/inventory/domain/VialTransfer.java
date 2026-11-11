package com.pai.api.inventory.domain;

import java.util.Objects;
import java.util.UUID;

/**
 * Reglas de una entrega de frascos cerrados de un unico lote.
 *
 * <p>Es un calculo de dominio, no una reserva persistida. El llamador debe
 * bloquear el saldo de origen y guardar saldo, entrega y movimientos en una
 * misma transaccion. No representa cuota offline ni consumo clinico.
 */
public final class VialTransfer {
  private VialTransfer() {}

  public enum Status {
    IN_TRANSIT,
    RECEIVED
  }

  public record Assignment(
      UUID id,
      UUID institutionId,
      UUID lotId,
      UUID vaccinatorId,
      UUID campaignId,
      int vials,
      Status status) {
    public Assignment {
      Objects.requireNonNull(id, "id");
      Objects.requireNonNull(institutionId, "institutionId");
      Objects.requireNonNull(lotId, "lotId");
      Objects.requireNonNull(vaccinatorId, "vaccinatorId");
      Objects.requireNonNull(status, "status");
      if (vials <= 0) {
        throw new IllegalArgumentException("La cantidad de frascos debe ser positiva.");
      }
    }
  }

  public record Dispatch(Assignment assignment, int remainingVials) {}

  /** Descuenta el origen al despachar; lo enviado queda en transito. */
  public static Dispatch dispatch(
      UUID id, UUID institutionId, UUID lotId, UUID vaccinatorId, UUID campaignId,
      int availableVials, int vials) {
    if (availableVials < 0) {
      throw new IllegalArgumentException("El saldo no puede ser negativo.");
    }
    Assignment assignment = new Assignment(
        id, institutionId, lotId, vaccinatorId, campaignId, vials, Status.IN_TRANSIT);
    if (vials > availableVials) {
      throw new IllegalArgumentException("No hay suficientes frascos disponibles.");
    }
    return new Dispatch(assignment, availableVials - vials);
  }

  /**
   * Confirma solo recepciones completas. Una diferencia necesita un flujo de
   * incidencia y no se convierte automaticamente en existencias disponibles.
   */
  public static Assignment receive(Assignment assignment, UUID receivingUserId, int receivedVials) {
    Objects.requireNonNull(assignment, "assignment");
    Objects.requireNonNull(receivingUserId, "receivingUserId");
    if (!assignment.vaccinatorId().equals(receivingUserId)) {
      throw new IllegalArgumentException("Solo el vacunador asignado puede confirmar la recepcion.");
    }
    if (assignment.status() != Status.IN_TRANSIT) {
      throw new IllegalStateException("La entrega ya no esta en transito.");
    }
    if (receivedVials != assignment.vials()) {
      throw new IllegalArgumentException("La cantidad recibida no coincide; requiere una incidencia.");
    }
    return new Assignment(assignment.id(), assignment.institutionId(), assignment.lotId(),
        assignment.vaccinatorId(), assignment.campaignId(), assignment.vials(), Status.RECEIVED);
  }
}
