package com.pai.api.inventory;

import static org.assertj.core.api.Assertions.assertThat;
import static com.pai.api.inventory.InventoryMobileE2eTest.*;

import com.pai.api.inventory.service.InventoryService;
import com.pai.api.inventory.service.CustodyEventService;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.server.context.WebServerApplicationContext;
import org.springframework.jdbc.core.JdbcTemplate;

/** Spring, HTTP, SSE y transacciones reales con H2 y usuarios ficticios. */
class InventoryEventsHttpE2eTest {
  @Test
  void deliversBothEventsOverAuthenticatedHttp() throws Exception {
    try (var context = new SpringApplicationBuilder(TestApplication.class)
        .properties("spring.config.name=inventory-e2e", "server.port=0", "app.inventory.api-enabled=true",
            "spring.flyway.enabled=false", "spring.data.jpa.repositories.enabled=false",
            "spring.autoconfigure.exclude=org.springframework.boot.hibernate.autoconfigure.HibernateJpaAutoConfiguration")
        .run()) {
      var db = context.getBean(JdbcTemplate.class);
      db.execute("CREATE SCHEMA app");
      db.execute("CREATE TABLE app.vaccines (id UUID PRIMARY KEY, name VARCHAR)");
      db.execute("CREATE TABLE app.users (id UUID PRIMARY KEY, institution_id UUID, status VARCHAR)");
      db.execute("CREATE TABLE app.roles (id UUID PRIMARY KEY, code VARCHAR)");
      db.execute("CREATE TABLE app.user_roles (user_id UUID, role_id UUID)");
      db.execute("CREATE TABLE app.inventory_lots (id UUID PRIMARY KEY, institution_id UUID, vaccine_id UUID, manufacturer VARCHAR, lot_number VARCHAR, expires_on DATE, doses_per_vial INT, available_vials INT DEFAULT 0, created_by UUID)");
      db.execute("CREATE TABLE app.inventory_assignments (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, vaccinator_id UUID, vial_count INT, received_vials INT DEFAULT 0 NOT NULL, resolved_vials INT DEFAULT 0 NOT NULL, status VARCHAR, dispatched_by UUID, dispatched_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, received_at TIMESTAMP WITH TIME ZONE, campaign_id UUID)");
      db.execute("CREATE TABLE app.inventory_movements (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, assignment_id UUID, kind VARCHAR, vial_count INT, occurred_at TIMESTAMP WITH TIME ZONE, recorded_by UUID, note VARCHAR)");
      db.execute("CREATE TABLE app.inventory_custody_events (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, assignment_id UUID, vial_count INT, status VARCHAR, reported_by UUID, report_note VARCHAR, reported_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, confirmed_by UUID, confirmed_at TIMESTAMP WITH TIME ZONE, confirmation_note VARCHAR)");
      db.execute("CREATE TABLE app.inventory_installation_reservations (id UUID PRIMARY KEY, institution_id UUID, assignment_id UUID, vial_count INT)");
      var lot = UUID.randomUUID();
      var role = UUID.randomUUID();
      db.update("INSERT INTO app.vaccines VALUES (?, 'Vacuna ficticia')", VACCINE);
      db.update("INSERT INTO app.users VALUES (?, ?, 'ACTIVE')", VACCINATOR, INST);
      db.update("INSERT INTO app.roles VALUES (?, 'VACCINATOR')", role);
      db.update("INSERT INTO app.user_roles VALUES (?, ?)", VACCINATOR, role);
      db.update("INSERT INTO app.inventory_lots (id,institution_id,vaccine_id,lot_number,expires_on,doses_per_vial,available_vials) VALUES (?,?,?,?,?,?,?)",
          lot, INST, VACCINE, "Lote ficticio", LocalDate.now().plusDays(10), 10, 5);
      int port = ((WebServerApplicationContext) context).getWebServer().getPort();
      var vaccinatorEvents = subscribe(port, "test-vaccinator");
      var adminEvents = subscribe(port, "test-admin");
      var inventory = context.getBean(InventoryService.class);
      var assignment = UUID.randomUUID();
      inventory.dispatch(ADMIN, INST, UUID.randomUUID(), assignment, lot, VACCINATOR, 3, Instant.now(), "Entrega ficticia");
      assertThat(vaccinatorEvents.get(15, TimeUnit.SECONDS)).contains("DELIVERY_CREATED", assignment.toString());
      // La recepción física se representa en el fixture; no prueba el formulario.
      db.update("UPDATE app.inventory_assignments SET status='RECEIVED', received_vials=3 WHERE id=?", assignment);
      context.getBean(CustodyEventService.class).report(VACCINATOR, INST, UUID.randomUUID(), assignment, 1, "RETURN", "Devolución ficticia");
      assertThat(adminEvents.get(15, TimeUnit.SECONDS)).contains("RETURN_DECLARED", assignment.toString());
    }
  }
}
