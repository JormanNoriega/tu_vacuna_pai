package com.pai.api.shared.util;

import java.util.Locale;
import java.util.Map;

/**
 * Normalizacion canonica de documentos de identidad (autoridad final en el
 * backend). Convierte una entrada como {@code "CC 12.345.678"} en su forma
 * canonica {@code "12345678"} y valida el formato segun el tipo de documento.
 *
 * <p>La unicidad SIEMPRE se evalua sobre la forma normalizada, de modo que
 * variaciones de separadores, espacios o mayusculas no crean duplicados.
 *
 * <p>Las reglas por tipo viven en {@link #RULES}, un unico mapa que actua como
 * contrato espejo del movil: {@code digitsOnly}, longitud minima y maxima. Los
 * tipos {@code AS}/{@code MS} (sin identificacion) se tratan provisionalmente
 * como alfanumericos 4-20 porque el modelo de datos actual exige
 * {@code document_number}; permitir su ausencia queda como evolucion futura.
 */
public final class DocumentNormalizer {

  /** Regla de formato para un tipo de documento. */
  public record Rule(boolean digitsOnly, int minLength, int maxLength) {}

  /** Contrato unico de reglas por tipo (espejo del movil). */
  public static final Map<String, Rule> RULES = Map.ofEntries(
      Map.entry("CC", new Rule(true, 6, 10)),
      Map.entry("TI", new Rule(true, 6, 11)),
      Map.entry("RC", new Rule(true, 6, 11)),
      Map.entry("CN", new Rule(true, 6, 11)),
      Map.entry("CE", new Rule(false, 4, 20)),
      Map.entry("PA", new Rule(false, 4, 20)),
      Map.entry("PPT", new Rule(false, 4, 20)),
      Map.entry("PE", new Rule(false, 4, 20)),
      Map.entry("SC", new Rule(false, 4, 20)),
      Map.entry("CD", new Rule(false, 4, 20)),
      Map.entry("DE", new Rule(false, 4, 20)),
      Map.entry("AS", new Rule(false, 4, 20)),
      Map.entry("MS", new Rule(false, 4, 20)));

  private DocumentNormalizer() {}

  /**
   * Forma canonica de un numero de documento: sin espacios, puntos ni
   * guiones, en mayusculas. Devuelve null para entradas vacias.
   */
  public static String normalize(String raw) {
    if (raw == null) {
      return null;
    }
    String s = raw.trim().replaceAll("[.\\s-]+", "").toUpperCase(Locale.ROOT);
    return s.isEmpty() ? null : s;
  }

  /**
   * Normaliza el tipo de documento (trim + mayusculas). Devuelve null para
   * entradas vacias.
   */
  public static String normalizeType(String raw) {
    if (raw == null) {
      return null;
    }
    String s = raw.trim().toUpperCase(Locale.ROOT);
    return s.isEmpty() ? null : s;
  }

  /** Regla del tipo, o null si el tipo no esta en el catalogo. */
  public static Rule ruleFor(String type) {
    if (type == null) {
      return null;
    }
    return RULES.get(type.trim().toUpperCase(Locale.ROOT));
  }

  /**
   * Valida que el numero normalizado sea coherente con el tipo, segun
   * {@link #RULES}: solo digitos para CC/TI/RC/CN y alfanumerico para el resto,
   * dentro del rango de longitud de cada tipo.
   */
  public static boolean isValidForType(String normalized, String type) {
    if (normalized == null || type == null) {
      return false;
    }
    Rule rule = ruleFor(type);
    if (rule == null) {
      return false;
    }
    if (normalized.length() < rule.minLength() || normalized.length() > rule.maxLength()) {
      return false;
    }
    return rule.digitsOnly() ? normalized.matches("\\d+") : normalized.matches("[A-Z0-9]+");
  }
}
