package com.pai.api.reports.export;

/**
 * Paleta de colores oficial para encabezados y filas del reporte Excel PAI.
 * Coincide con la especificacion del modulo oficial de exportacion.
 */
public final class ReportCategoryColors {

  private ReportCategoryColors() {}

  // Encabezados de Categorias (Fila 0)
  public static final String BASIC_DATA = "4472C4"; // Azul intermedio
  public static final String COMPLEMENTARY_DATA = "70AD47"; // Verde oliva/fresco
  public static final String MEDICAL_HISTORY = "FFC000"; // Amarillo dorado
  public static final String USER_CONDITION = "F4B084"; // Salmon suave
  public static final String ANTECEDENT_HISTORY = "92D050"; // Verde lima
  public static final String MOTHER_DATA = "E74C3C"; // Rojo coral
  public static final String CAREGIVER_DATA = "9B59B6"; // Purpura / violeta
  public static final String VACCINATION_SCHEME = "44546A"; // Azul pizarra
  public static final String NURSE_DATA = "3498DB"; // Azul cielo brillante

  // Categorias de vacunas dinamicas (Fila 0 alternada)
  public static final String VACCINE_DARK = "1ABC9C"; // Turquesa oscuro
  public static final String VACCINE_LIGHT = "5FD8D1"; // Turquesa claro

  // Subcampos de vacunas dinamicas (Fila 1 alternada)
  public static final String VACCINE_FIELD_DARK = "B8E7E1"; // Aguamarina pastel
  public static final String VACCINE_FIELD_LIGHT = "DAF5F2"; // Aguamarina pastel claro

  // Subencabezados fijos y enfermera (Fila 1)
  public static final String HEADER_ROW = "E7E6E6"; // Gris claro
  public static final String NURSE_FIELD = "DAF5F2"; // Aguamarina claro

  // Diseno cebra para filas de datos (Fila 2 en adelante)
  public static final String ROW_EVEN = "FFFFFF"; // Blanco
  public static final String ROW_ODD = "F2F2F2"; // Gris tenue
}
