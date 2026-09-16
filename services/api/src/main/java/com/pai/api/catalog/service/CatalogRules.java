package com.pai.api.catalog.service;

import java.util.Set;

/**
 * Validaciones de opciones del catalogo compartidas entre servicios (DRY).
 * Antes se repetian como metodos privados en {@code VaccineService}
 * ({@code validateGlobalType}, {@code validateTemplateType},
 * {@code requireValue}) y en {@code InstitutionVaccineService}
 * ({@code LOCAL_OPTION_TYPES}).
 */
public final class CatalogRules {

  private static final Set<String> GLOBAL_TYPES = Set.of("dose", "pneumococcalType");
  private static final Set<String> TEMPLATE_TYPES =
      Set.of("laboratory", "syringe", "dropper", "observation");
  private static final Set<String> LOCAL_TYPES =
      Set.of("laboratory", "syringe", "dropper", "observation");

  private CatalogRules() {}

  public static void requireValue(String value) {
    if (value == null || value.trim().isEmpty()) {
      throw new IllegalArgumentException("El valor no puede estar vacio.");
    }
  }

  public static void requireGlobalOptionType(String type) {
    if (!GLOBAL_TYPES.contains(type)) {
      throw new IllegalArgumentException("Tipo de opcion global invalido.");
    }
  }

  public static void requireTemplateType(String type) {
    if (!TEMPLATE_TYPES.contains(type)) {
      throw new IllegalArgumentException("Tipo de template invalido.");
    }
  }

  public static void requireLocalOptionType(String type) {
    if (!LOCAL_TYPES.contains(type)) {
      throw new IllegalArgumentException("Tipo de opcion local invalido.");
    }
  }
}
