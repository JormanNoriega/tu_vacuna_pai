package com.pai.api.inventory.service;

import java.util.regex.Pattern;

/** Solo configuracion explicita de una base desechable local; nunca lee .env.local. */
final class DisposablePostgresConfig {
  private static final Pattern URL = Pattern.compile(
      "jdbc:postgresql://127\\.0\\.0\\.1:[1-9][0-9]{0,4}/pai_inventory_test_[a-f0-9]{32}");

  static String validate(String url, String user, String password) {
    if (url == null || !URL.matcher(url).matches()
        || !"pai_inventory_test_runner".equals(user)
        || password == null || password.isBlank()) {
      throw new IllegalArgumentException("Se requiere URL local estricta, usuario dedicado y contraseña explícita.");
    }
    return url.substring(url.lastIndexOf('/') + 1);
  }

  private DisposablePostgresConfig() {}
}
