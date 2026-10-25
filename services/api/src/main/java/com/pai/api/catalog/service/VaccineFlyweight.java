package com.pai.api.catalog.service;

import com.pai.api.attentions.dto.DoseExtrinsicContext;

/**
 * Interfaz Flyweight (GoF) que declara las operaciones sobre los datos intrinsecos
 * de una vacuna del catalogo PAI y admite el estado extrinseco contextual de la aplicacion.
 */
public interface VaccineFlyweight {

  String getCode();

  String getName();

  String getCategory();

  boolean isRequiresLot();

  boolean isRequiresSyringe();

  /**
   * Genera un resumen clinico de la dosis combinando el estado intrinseco compartido
   * (nombre, codigo, categoria) con el estado extrinseco de la aplicacion particular.
   *
   * @param context Estado extrinseco particular de la aplicacion
   * @return Cadena descriptiva formateada de la dosis aplicada
   */
  String formatDoseSummary(DoseExtrinsicContext context);
}
