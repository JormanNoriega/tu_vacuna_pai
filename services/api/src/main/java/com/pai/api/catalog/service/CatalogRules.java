package com.pai.api.catalog.service;

import com.pai.api.catalog.CatalogFieldType;
import java.util.function.Predicate;

/**
 * Validaciones de opciones del catalogo compartidas entre servicios (DRY). La
 * clasificacion de tipos vive en {@link CatalogFieldType}; aqui solo se aplican
 * las reglas.
 */
public final class CatalogRules {

  private CatalogRules() {}

  public static void requireValue(String value) {
    if (value == null || value.trim().isEmpty()) {
      throw new IllegalArgumentException("El valor no puede estar vacio.");
    }
  }

  public static void requireGlobalOptionType(String type) {
    if (!is(type, CatalogFieldType::isGlobal)) {
      throw new IllegalArgumentException("Tipo de opcion global invalido.");
    }
  }

  public static void requireTemplateType(String type) {
    if (!is(type, CatalogFieldType::isOperational)) {
      throw new IllegalArgumentException("Tipo de template invalido.");
    }
  }

  public static void requireLocalOptionType(String type) {
    if (!is(type, CatalogFieldType::isOperational)) {
      throw new IllegalArgumentException("Tipo de opcion local invalido.");
    }
  }

  private static boolean is(String type, Predicate<CatalogFieldType> predicate) {
    CatalogFieldType field = CatalogFieldType.from(type);
    return field != null && predicate.test(field);
  }
}
