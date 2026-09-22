package com.pai.api.catalog.entity;

import java.util.UUID;

/**
 * Contrato comun de las opciones del catalogo global (opciones y templates),
 * que comparten forma y ciclo de vida. Permite a {@code VaccineService} tratar
 * ambas con un mismo algoritmo (OCP/DRY).
 */
public interface CatalogOption {

  UUID getId();

  UUID getVaccineId();

  String getFieldType();

  String getValue();

  String getDisplayName();

  int getSortOrder();

  boolean isDefault();

  boolean isActive();

  long getVersion();

  void update(String value, String display, int order, boolean def, boolean active, UUID actor);
}
