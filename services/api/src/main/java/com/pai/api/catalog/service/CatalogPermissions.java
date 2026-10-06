package com.pai.api.catalog.service;

/**
 * Nombres canonicos de permisos del catalogo y expresiones SpEL listas para
 * {@code @PreAuthorize}. Evita repetir los literales (y el SpEL combinado) en
 * los controllers (DRY), al estilo de {@code IdentityPermissions}.
 */
public final class CatalogPermissions {

  public static final String GLOBAL_READ = "CATALOG_GLOBAL_READ";
  public static final String GLOBAL_WRITE = "CATALOG_GLOBAL_WRITE";
  public static final String CONFIG_READ = "CATALOG_CONFIG_READ";
  public static final String CONFIG_WRITE = "CATALOG_CONFIG_WRITE";

  /** Lectura del catalogo con cualquiera de los dos alcances (global o institucional). */
  public static final String READ = "@authorization.hasPermission(authentication, '" + GLOBAL_READ
      + "') or @authorization.hasPermission(authentication, '" + CONFIG_READ + "')";

  private CatalogPermissions() {}
}
