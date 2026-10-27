package com.pai.api.attentions.dto;

import com.pai.api.catalog.service.VaccineFlyweight;
import java.util.Objects;

/**
 * DTO clinico que asocia el estado extrinseco particular de una dosis
 * con la referencia al objeto Flyweight intrinseco compartido en memoria.
 */
public class AppliedDoseItem {

  private final DoseExtrinsicContext context;
  private final VaccineFlyweight vaccine;

  public AppliedDoseItem(DoseExtrinsicContext context, VaccineFlyweight vaccine) {
    this.context = Objects.requireNonNull(context, "context no puede ser nulo");
    this.vaccine = Objects.requireNonNull(vaccine, "vaccine flyweight no puede ser nulo");
  }

  public DoseExtrinsicContext getContext() {
    return context;
  }

  public VaccineFlyweight getVaccine() {
    return vaccine;
  }

  public String getSummary() {
    return vaccine.formatDoseSummary(context);
  }
}
