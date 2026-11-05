package com.pai.api.reports.service;

import java.util.Locale;

/** Formateador de tipos de carnet de vacunacion. */
public final class CarnetTypeFormatter {

  private CarnetTypeFormatter() {}

  public static String format(String raw) {
    if (raw == null || raw.isBlank()) {
      return "";
    }
    String normalized = raw.trim();
    return switch (normalized) {
      case "carneVacunacionInfantil", "INFANTIL" -> "CARNÉ DE VACUNACIÓN INFANTIL";
      case "carneVacunacionAdultos", "ADULTOS" -> "CARNÉ/CERTIFICADO DE VACUNACIÓN DE ADULTOS";
      case "carneVacunacionInternacional", "INTERNACIONAL" ->
          "CARNÉ/CERTIFICADO INTERNACIONAL DE VACUNACIÓN";
      case "tarjetasUnificadasVacunacionAdultos" -> "TARJETAS UNIFICADAS DE VACUNACIÓN - TUV ADULTOS";
      case "tarjetasUnificadasVacunacionNinos" -> "TARJETAS UNIFICADAS DE VACUNACIÓN - TUV NIÑOS";
      default -> normalized.toUpperCase(Locale.ROOT);
    };
  }
}
