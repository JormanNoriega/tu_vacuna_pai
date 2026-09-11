package com.pai.api.shared.util;

import java.util.Locale;

/**
 * Normalizacion canonica de documentos de identidad (autoridad final en el
 * backend). Convierte una entrada como {@code "CC 12.345.678"} en su forma
 * canonica {@code "12345678"} y valida el formato segun el tipo de documento.
 *
 * <p>La unicidad SIEMPRE se evalua sobre la forma normalizada, de modo que
 * variaciones de separadores, espacios o mayusculas no crean duplicados.
 */
public final class DocumentNormalizer {

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

    /**
     * Valida que el numero normalizado sea coherente con el tipo:
     * <ul>
     *   <li>CC: solo digitos (6 a 10).</li>
     *   <li>TI, CE, PASAPORTE: alfanumerico (4 a 20).</li>
     * </ul>
     */
    public static boolean isValidForType(String normalized, String type) {
        if (normalized == null || type == null) {
            return false;
        }
        return switch (type) {
            case "CC" -> normalized.matches("\\d{6,10}");
            case "TI", "CE", "PASAPORTE" -> normalized.matches("[A-Z0-9]{4,20}");
            default -> false;
        };
    }
}
