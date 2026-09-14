package com.pai.api.identity.service;

import java.util.UUID;

/**
 * Alcance institucional efectivo de un actor autenticado, derivado por
 * {@link DataScope}. Distingue dos estados:
 *
 * <ul>
 *   <li>{@code restricted}: el actor solo puede acceder a recursos de
 *       {@code institutionId}. Es el caso de ADMIN_INSTITUTION, VACCINATOR y
 *       READ_ONLY.</li>
 *   <li>{@code unrestricted}: el actor puede acceder a recursos de cualquier
 *       institucion (por ahora, quien tiene {@code INSTITUTION_WRITE}). Cada
 *       caso de uso futuro decide que institucion puede solicitar y que
 *       permiso adicional exige: {@code unrestricted} no significa acceso
 *       global ilimitado en todos los modulos.</li>
 * </ul>
 *
 * @param unrestricted true cuando el alcance no esta atado a una institucion.
 * @param institutionId institucion efectiva; null solo cuando
 *        {@code unrestricted} es true.
 */
public record InstitutionScope(boolean unrestricted, UUID institutionId) {

  public static InstitutionScope restricted(UUID institutionId) {
    return new InstitutionScope(false, institutionId);
  }

  public static InstitutionScope global() {
    return new InstitutionScope(true, null);
  }
}
