package com.pai.api.catalog;

import java.util.Set;

/**
 * Tipos de campo ({@code fieldType}) del catalogo de vacunas. Fuente unica de
 * verdad para validaciones y logica de seleccion, en lugar de literales
 * repartidos por los servicios.
 *
 * <p>Los DTOs y las entidades siguen transportando {@code String} en la
 * frontera (contrato HTTP y columnas); este enum es el tipo interno. Agregar un
 * tipo nuevo se hace aqui y en su clasificacion, sin tocar cada servicio (OCP).
 */
public enum CatalogFieldType {
  DOSE("dose"),
  PNEUMOCOCCAL_TYPE("pneumococcalType"),
  LABORATORY("laboratory"),
  SYRINGE("syringe"),
  DROPPER("dropper"),
  OBSERVATION("observation");

  private static final Set<CatalogFieldType> GLOBAL = Set.of(DOSE, PNEUMOCOCCAL_TYPE);
  private static final Set<CatalogFieldType> OPERATIONAL =
      Set.of(LABORATORY, SYRINGE, DROPPER, OBSERVATION);

  private final String value;

  CatalogFieldType(String value) {
    this.value = value;
  }

  /** Valor tal como viaja en DTOs, entidades y payloads. */
  public String value() {
    return value;
  }

  /** Tipo de opcion global (dosis / tipo de neumococo). */
  public boolean isGlobal() {
    return GLOBAL.contains(this);
  }

  /** Tipo de opcion operativa (laboratorio, jeringa, gotero, observacion). */
  public boolean isOperational() {
    return OPERATIONAL.contains(this);
  }

  /** Indica si el valor dado corresponde a este tipo. */
  public boolean matches(String candidate) {
    return value.equals(candidate);
  }

  /** Resuelve el tipo a partir de su valor, o {@code null} si no es conocido. */
  public static CatalogFieldType from(String value) {
    if (value == null) {
      return null;
    }
    for (CatalogFieldType type : values()) {
      if (type.value.equals(value)) {
        return type;
      }
    }
    return null;
  }
}
