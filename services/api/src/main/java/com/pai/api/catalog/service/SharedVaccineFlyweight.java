package com.pai.api.catalog.service;

import com.pai.api.attentions.dto.DoseExtrinsicContext;
import java.util.Objects;

/**
 * Flyweight Concreto que almacena exclusivamente el Estado Intrinseco
 * compartido e inmutable de una definicion de vacuna del catalogo PAI.
 *
 * <p>Sus atributos son {@code final} y no posee mutadores, garantizando
 * inmutabilidad estricta y seguridad thread-safe en entornos concurrentes.
 */
public final class SharedVaccineFlyweight implements VaccineFlyweight {

  private final String code;
  private final String name;
  private final String category;
  private final boolean requiresLot;
  private final boolean requiresSyringe;

  public SharedVaccineFlyweight(
      String code,
      String name,
      String category,
      boolean requiresLot,
      boolean requiresSyringe) {
    this.code = Objects.requireNonNull(code, "code no puede ser nulo").trim().toUpperCase();
    this.name = Objects.requireNonNull(name, "name no puede ser nulo").trim();
    this.category = (category == null || category.isBlank()) ? "BIOLOGICO_PAI" : category.trim();
    this.requiresLot = requiresLot;
    this.requiresSyringe = requiresSyringe;
  }

  @Override
  public String getCode() {
    return code;
  }

  @Override
  public String getName() {
    return name;
  }

  @Override
  public String getCategory() {
    return category;
  }

  @Override
  public boolean isRequiresLot() {
    return requiresLot;
  }

  @Override
  public boolean isRequiresSyringe() {
    return requiresSyringe;
  }

  @Override
  public String formatDoseSummary(DoseExtrinsicContext context) {
    Objects.requireNonNull(context, "El contexto extrinseco no puede ser nulo");
    return String.format(
        "[%s - %s] %s aplicada a paciente %s (Lote: %s, Fecha: %s, Aplicador: %s)",
        code,
        category,
        name,
        context.patientDocument(),
        context.lotNumber(),
        context.applicationDate(),
        context.healthWorker());
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    SharedVaccineFlyweight that = (SharedVaccineFlyweight) o;
    return requiresLot == that.requiresLot
        && requiresSyringe == that.requiresSyringe
        && code.equals(that.code)
        && name.equals(that.name)
        && category.equals(that.category);
  }

  @Override
  public int hashCode() {
    return Objects.hash(code, name, category, requiresLot, requiresSyringe);
  }

  @Override
  public String toString() {
    return "SharedVaccineFlyweight{" +
        "code='" + code + '\'' +
        ", name='" + name + '\'' +
        ", category='" + category + '\'' +
        ", requiresLot=" + requiresLot +
        ", requiresSyringe=" + requiresSyringe +
        '}';
  }
}
