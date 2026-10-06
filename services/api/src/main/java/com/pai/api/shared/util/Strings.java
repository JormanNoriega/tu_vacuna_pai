package com.pai.api.shared.util;

import java.util.List;
import java.util.Map;

/**
 * Utilidades de normalizacion de texto y colecciones compartidas por los
 * servicios. Evita la duplicacion textual de helpers privados
 * ({@code blankToNull}, {@code safe}, {@code trimToNull}) en cada servicio.
 */
public final class Strings {

  private Strings() {}

  /** Devuelve {@code null} si el valor es nulo o solo espacios en blanco. */
  public static String blankToNull(String value) {
    if (value == null) {
      return null;
    }
    String trimmed = value.trim();
    return trimmed.isEmpty() ? null : trimmed;
  }

  /** Alias de {@link #blankToNull(String)}: normaliza a {@code null} un texto en blanco. */
  public static String trimToNull(String value) {
    return blankToNull(value);
  }

  /** Devuelve una lista vacia inmutable si el argumento es {@code null}. */
  public static <T> List<T> safe(List<T> list) {
    return list == null ? List.of() : list;
  }

  /** Devuelve un mapa vacio inmutable si el argumento es {@code null}. */
  public static <K, V> Map<K, V> safe(Map<K, V> map) {
    return map == null ? Map.of() : map;
  }
}
