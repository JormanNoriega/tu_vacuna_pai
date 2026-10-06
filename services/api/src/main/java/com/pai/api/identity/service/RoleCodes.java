package com.pai.api.identity.service;

/**
 * Codigos canonicos de rol del dominio de identidad. Evita repetir los literales
 * en los servicios (DRY); agregar un rol se hace aqui.
 */
public final class RoleCodes {

  public static final String SUPER_ADMIN = "SUPER_ADMIN";
  public static final String ADMIN_INSTITUTION = "ADMIN_INSTITUTION";
  public static final String VACCINATOR = "VACCINATOR";
  public static final String READ_ONLY = "READ_ONLY";

  private RoleCodes() {}
}
