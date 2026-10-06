package com.pai.api.identity.service;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.entity.UserEntity;

/**
 * Reglas de dominio compartidas del modulo de identidad. Centraliza
 * normalizaciones y validaciones que se duplicaban como helpers privados en
 * {@link UserService} e {@link InstitutionService} (DRY).
 */
public final class IdentityRules {

  private IdentityRules() {}

  /**
   * Parsea el estado de un {@link UserEntity}. Acepta variaciones de
   * mayusculas y espacios en blanco.
   *
   * @throws IllegalArgumentException si el estado no es {@code ACTIVE} o
   *                                  {@code INACTIVE}
   */
  public static UserEntity.Status parseUserStatus(String status) {
    return parseEnum(UserEntity.Status.class, status);
  }

  /**
   * Parsea el estado de una {@link InstitutionEntity}.
   *
   * @throws IllegalArgumentException si el estado no es {@code ACTIVE} o
   *                                  {@code INACTIVE}
   */
  public static InstitutionEntity.Status parseInstitutionStatus(String status) {
    return parseEnum(InstitutionEntity.Status.class, status);
  }

  private static <E extends Enum<E>> E parseEnum(Class<E> type, String status) {
    try {
      return Enum.valueOf(type, status.trim().toUpperCase());
    } catch (IllegalArgumentException ex) {
      throw new IllegalArgumentException("Estado invalido. Usa ACTIVE o INACTIVE.");
    }
  }
}
