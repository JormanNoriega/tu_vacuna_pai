package com.pai.api.inventory;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Path;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.server.context.WebServerApplicationContext;
import org.springframework.jdbc.core.JdbcTemplate;

/** Opt-in: HTTP loopback + H2 en memoria; nunca usa .env.local ni PostgreSQL. */
@EnabledIfEnvironmentVariable(named = "PAI_RUN_LOCAL_READ_E2E", matches = "true")
class InventoryReadViewsLocalE2eTest {
  private static final UUID LOT = UUID.fromString("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
  private static final UUID ASSIGNMENT = UUID.fromString("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb");
  private static final UUID RECEIPT = UUID.fromString("cccccccc-cccc-4ccc-8ccc-cccccccccccc");
  private static final UUID EVENT = UUID.fromString("dddddddd-dddd-4ddd-8ddd-dddddddddddd");
  private static final UUID RESOLUTION = UUID.fromString("eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee");

  @Test
  void viewsUseRealLocalApiWithoutWritingOrLeakingAcrossPermissions() throws Exception {
    try (var context = new SpringApplicationBuilder(InventoryMobileE2eTest.TestApplication.class)
        .properties("spring.config.name=inventory-e2e", "server.port=0", "server.address=127.0.0.1",
            "app.inventory.api-enabled=true", "spring.flyway.enabled=false",
            "spring.data.jpa.repositories.enabled=false",
            "spring.autoconfigure.exclude=org.springframework.boot.hibernate.autoconfigure.HibernateJpaAutoConfiguration")
        .run()) {
      var db = context.getBean(JdbcTemplate.class);
      db.execute("CREATE SCHEMA app");
      db.execute("CREATE TABLE app.vaccines (id UUID PRIMARY KEY, name VARCHAR)");
      db.execute("CREATE TABLE app.inventory_lots (id UUID PRIMARY KEY, institution_id UUID, vaccine_id UUID, "
          + "lot_number VARCHAR, available_vials INT)");
      db.execute("CREATE TABLE app.inventory_assignments (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, "
          + "vaccinator_id UUID, vial_count INT, received_vials INT, resolved_vials INT, status VARCHAR)");
      db.execute("CREATE TABLE app.inventory_receipts (id UUID PRIMARY KEY, institution_id UUID, assignment_id UUID, "
          + "lot_id UUID, received_by UUID, vials INT, difference_note VARCHAR, received_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)");
      db.execute("CREATE TABLE app.inventory_custody_events (id UUID PRIMARY KEY, institution_id UUID, assignment_id UUID, "
          + "lot_id UUID, vial_count INT, status VARCHAR, reported_by UUID, report_note VARCHAR, "
          + "reported_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, confirmed_by UUID, "
          + "confirmed_at TIMESTAMP WITH TIME ZONE, confirmation_note VARCHAR)");
      db.execute("CREATE TABLE app.inventory_difference_resolutions (id UUID PRIMARY KEY, institution_id UUID, "
          + "assignment_id UUID, lot_id UUID, kind VARCHAR, vial_count INT, note VARCHAR, recorded_by UUID, "
          + "recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)");
      db.execute("CREATE TABLE app.inventory_depot_regularizations (id UUID PRIMARY KEY, institution_id UUID, "
          + "resolution_id UUID, vial_count INT)");
      db.execute("CREATE TABLE app.inventory_movements (id UUID PRIMARY KEY)");
      db.update("INSERT INTO app.vaccines VALUES (?,?)", InventoryMobileE2eTest.VACCINE, "Vacuna aislada");
      db.update("INSERT INTO app.inventory_lots VALUES (?,?,?,?,?)", LOT, InventoryMobileE2eTest.INST,
          InventoryMobileE2eTest.VACCINE, "LOTE-LECTURA", 7);
      db.update("INSERT INTO app.inventory_assignments VALUES (?,?,?,?,10,8,2,'CLOSED_WITH_DIFFERENCE')",
          ASSIGNMENT, InventoryMobileE2eTest.INST, LOT, InventoryMobileE2eTest.VACCINATOR);
      db.update("INSERT INTO app.inventory_receipts (id,institution_id,assignment_id,lot_id,received_by,vials,difference_note) "
          + "VALUES (?,?,?,?,?,8,?)", RECEIPT, InventoryMobileE2eTest.INST, ASSIGNMENT, LOT,
          InventoryMobileE2eTest.VACCINATOR, "Faltaron dos");
      db.update("INSERT INTO app.inventory_custody_events (id,institution_id,assignment_id,lot_id,vial_count,status,reported_by,report_note) "
          + "VALUES (?,?,?,?,3,'RETURN_PENDING',?,?)", EVENT, InventoryMobileE2eTest.INST, ASSIGNMENT, LOT,
          InventoryMobileE2eTest.VACCINATOR, "Devolución contada");
      db.update("INSERT INTO app.inventory_difference_resolutions (id,institution_id,assignment_id,lot_id,kind,vial_count,note,recorded_by) "
          + "VALUES (?,?,?,?,'DISPATCH_CORRECTION',2,?,?)", RESOLUTION, InventoryMobileE2eTest.INST, ASSIGNMENT,
          LOT, "Acta de prueba", InventoryMobileE2eTest.ADMIN);
      var before = snapshot(db);
      int port = ((WebServerApplicationContext) context).getWebServer().getPort();
      Path app = Path.of("..", "..", "apps", "mobile").toAbsolutePath().normalize();
      var process = new ProcessBuilder("cmd", "/c", "flutter.bat", "test",
          "test/features/inventory/inventory_read_views_local_e2e_test.dart")
          .directory(app.toFile()).redirectErrorStream(true);
      process.environment().put("PAI_READ_E2E_URL", "http://127.0.0.1:" + port + "/api/v1");
      var flutter = process.start();
      var output = new StringBuilder();
      var reader = Thread.ofVirtual().start(() -> {
        try (var lines = flutter.inputReader()) { lines.lines().forEach(line -> output.append(line).append('\n')); }
        catch (java.io.IOException e) { output.append(e.getMessage()); }
      });
      assertThat(flutter.waitFor(120, TimeUnit.SECONDS)).as("Flutter debe terminar").isTrue();
      reader.join();
      assertThat(flutter.exitValue()).as("Vistas con API local: %s", output).isZero();
      assertThat(snapshot(db)).as("Las vistas no deben modificar ninguna tabla de inventario del fixture").isEqualTo(before);
      System.out.println("E2E de lectura local: referencias, permisos y errores verificados; tablas sin cambios.");
    }
  }

  private static List<List<java.util.Map<String, Object>>> snapshot(JdbcTemplate db) {
    return List.of("inventory_lots", "inventory_assignments", "inventory_receipts", "inventory_custody_events",
        "inventory_difference_resolutions", "inventory_depot_regularizations", "inventory_movements").stream()
        .map(table -> db.queryForList("SELECT * FROM app." + table + " ORDER BY id")).toList();
  }
}
