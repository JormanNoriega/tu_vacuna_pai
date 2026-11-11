package com.pai.api.inventory;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.DriverManager;
import java.util.Properties;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

/** Ejecucion explicita sobre la base configurada; nunca se activa en pruebas ordinarias. */
@EnabledIfEnvironmentVariable(named = "INVENTORY_APPLY_PG_MIGRATION", matches = "true")
class InventoryPostgresMigrationTest {
  @Test
  void migrateUsingFlywayAndVerifyInventoryTables() throws Exception {
    Properties settings = new Properties();
    try (var reader = Files.newBufferedReader(Path.of(".env.local"))) {
      settings.load(reader);
    }
    String url = settings.getProperty("DB_URL");
    String user = settings.getProperty("DB_USERNAME");
    String password = settings.getProperty("DB_PASSWORD");
    String marker = System.getenv("INVENTORY_EXPECTED_DB_MARKER");
    assertThat(marker).as("Se requiere un marcador de la base autorizada").isNotBlank();
    assertThat(user != null && user.endsWith("." + marker))
        .as("El usuario del pooler debe identificar el proyecto Supabase autorizado").isTrue();
    Flyway flyway = Flyway.configure().dataSource(url, user, password)
        .schemas("app").locations("classpath:db/migration").validateOnMigrate(true).load();
    flyway.migrate();
    try (var connection = DriverManager.getConnection(url, user, password);
         var statement = connection.createStatement();
         var result = statement.executeQuery("SELECT count(*) FROM information_schema.tables "
             + "WHERE table_schema='app' AND table_name IN "
             + "('inventory_lots','inventory_assignments','inventory_movements')")) {
      assertThat(result.next()).isTrue();
      assertThat(result.getInt(1)).isEqualTo(3);
    }
  }
}
