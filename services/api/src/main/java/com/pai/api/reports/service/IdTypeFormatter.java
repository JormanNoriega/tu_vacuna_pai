package com.pai.api.reports.service;

import java.util.Map;

/** Formateador de tipos de identificacion colombianos a sigla estandar. */
public final class IdTypeFormatter {

  private IdTypeFormatter() {}

  private static final Map<String, String> ABBREVIATIONS =
      Map.ofEntries(
          Map.entry("CN - Certificado de Nacido Vivo", "CN"),
          Map.entry("RC - Registro Civil", "RC"),
          Map.entry("TI - Tarjeta de Identidad", "TI"),
          Map.entry("CC - Cédula de Ciudadanía", "CC"),
          Map.entry("AS - Adulto sin Identificación", "AS"),
          Map.entry("MS - Menor sin Identificación", "MS"),
          Map.entry("CE - Cédula de Extranjería", "CE"),
          Map.entry("PA - Pasaporte", "PA"),
          Map.entry("CD - Carné Diplomático", "CD"),
          Map.entry("SC - Salvoconducto", "SC"),
          Map.entry("PE - Permiso Especial de Permanencia", "PE"),
          Map.entry("PPT - Permiso por Protección Temporal", "PPT"),
          Map.entry("DE - Documento Extranjero", "DE"));

  public static String toAbbreviation(String idType) {
    if (idType == null || idType.isBlank()) {
      return "";
    }
    String found = ABBREVIATIONS.get(idType.trim());
    if (found != null) {
      return found;
    }
    // Si ya viene como sigla (CC, TI, RC, etc.)
    for (String abbr : ABBREVIATIONS.values()) {
      if (abbr.equalsIgnoreCase(idType.trim())) {
        return abbr;
      }
    }
    return idType.trim().toUpperCase();
  }
}
