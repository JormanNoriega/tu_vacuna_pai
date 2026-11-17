package com.pai.api.inventory.domain;

import java.util.HashSet;
import java.util.List;
import java.util.HashMap;
import java.util.Objects;
import java.util.UUID;

/**
 * Proyeccion aislada de cantidades registradas por custodio y lote.
 * No comprueba evidencia, permisos, aptitud, consumo ni identidad de frascos.
 * La persistencia debera verificar el origen y serializar cada operacion.
 */
public final class IndividualCustody {
  private IndividualCustody() {}

  public enum SourceType { RECEIPT, LEGACY_ASSIGNMENT }

  /** Una fuente historica no debe duplicarse como recepcion sintetica. */
  public record Source(SourceType type, UUID id) {
    public Source {
      Objects.requireNonNull(type, "type");
      Objects.requireNonNull(id, "id");
    }
  }

  /**
   * received y removed son frascos, no dosis. removed es la cantidad ya
   * atribuida a salidas o novedades registradas, no un consumo estimado.
   */
  public record Contribution(Source source, UUID assignmentId, UUID lotId, int received, int removed) {
    public Contribution {
      Objects.requireNonNull(source, "source");
      Objects.requireNonNull(assignmentId, "assignmentId");
      Objects.requireNonNull(lotId, "lotId");
      if (received <= 0 || removed < 0 || removed > received)
        throw new IllegalArgumentException("Cantidades de custodia incoherentes.");
      if (source.type() == SourceType.LEGACY_ASSIGNMENT && !source.id().equals(assignmentId))
        throw new IllegalArgumentException("El origen histórico debe identificar la entrega.");
    }
  }

  public record Projection(UUID institutionId, UUID custodianId, UUID lotId,
      List<Contribution> contributions, long received, long removed, long unaccounted) {
    public Projection {
      Objects.requireNonNull(institutionId, "institutionId");
      Objects.requireNonNull(custodianId, "custodianId");
      Objects.requireNonNull(lotId, "lotId");
      contributions = List.copyOf(contributions);
      var sources = new HashSet<Source>();
      var assignmentTypes = new HashMap<UUID, SourceType>();
      long actualReceived = 0;
      long actualRemoved = 0;
      for (var contribution : contributions) {
        if (!lotId.equals(contribution.lotId()) || !sources.add(contribution.source()))
          throw new IllegalArgumentException("Origen duplicado o lote distinto.");
        var priorType = assignmentTypes.putIfAbsent(contribution.assignmentId(), contribution.source().type());
        if (priorType != null && priorType != contribution.source().type())
          throw new IllegalArgumentException("No mezclar una entrega histórica con recepciones de la misma entrega.");
        actualReceived = Math.addExact(actualReceived, contribution.received());
        actualRemoved = Math.addExact(actualRemoved, contribution.removed());
      }
      if (received != actualReceived || removed != actualRemoved || unaccounted != received - removed)
        throw new IllegalArgumentException("La proyeccion no coincide con sus fuentes.");
    }
  }

  /** Los datos de entrada deben proceder de registros verificados, nunca de supuestos. */
  public static Projection project(UUID institutionId, UUID custodianId, UUID lotId,
      List<Contribution> contributions) {
    var copy = List.copyOf(contributions);
    long received = 0, removed = 0;
    for (var contribution : copy) {
      received = Math.addExact(received, contribution.received());
      removed = Math.addExact(removed, contribution.removed());
    }
    return new Projection(institutionId, custodianId, lotId, copy, received, removed, received - removed);
  }
}
