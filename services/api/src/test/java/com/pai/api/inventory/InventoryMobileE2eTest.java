package com.pai.api.inventory;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.ActiveUserAuthenticationConverter;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.inventory.controller.InventoryController;
import com.pai.api.inventory.controller.CampaignController;
import com.pai.api.inventory.controller.CustodyEventController;
import com.pai.api.inventory.service.InventoryService;
import com.pai.api.inventory.service.CampaignService;
import com.pai.api.inventory.service.CustodyEventService;
import com.pai.api.shared.exceptions.GlobalExceptionHandler;
import com.pai.api.shared.json.JsonSerializer;
import com.pai.api.shared.security.AuthorizationService;
import com.pai.api.shared.security.PermissionGuard;
import com.pai.api.shared.security.SecurityConfig;
import java.nio.file.Path;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import javax.sql.DataSource;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.boot.SpringBootConfiguration;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.server.context.WebServerApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Servidor local efimero para probar widgets reales contra la API real, sin credenciales reales. */
@EnabledIfEnvironmentVariable(named = "INVENTORY_RUN_MOBILE_E2E", matches = "true")
class InventoryMobileE2eTest {
  static final UUID INST = UUID.fromString("11111111-1111-4111-8111-111111111111");
  static final UUID ADMIN = UUID.fromString("22222222-2222-4222-8222-222222222222");
  static final UUID VACCINATOR = UUID.fromString("33333333-3333-4333-8333-333333333333");
  static final UUID VACCINE = UUID.fromString("44444444-4444-4444-8444-444444444444");
  static final UUID CAMPAIGN = UUID.fromString("55555555-5555-4555-8555-555555555555");

  @SpringBootConfiguration
  @EnableAutoConfiguration
  @EnableTransactionManagement
  @Import({InventoryController.class, CampaignController.class, CustodyEventController.class, InventoryService.class, CampaignService.class, CustodyEventService.class, DataScope.class, PermissionGuard.class,
      AuthorizationService.class, SecurityConfig.class, ActiveUserAuthenticationConverter.class,
      JsonSerializer.class, GlobalExceptionHandler.class, FixtureCatalog.class})
  static class TestApplication {
    @Bean DataSource dataSource() {
      return new DriverManagerDataSource("jdbc:h2:mem:inventory_e2e;MODE=PostgreSQL;DB_CLOSE_DELAY=-1", "sa", "");
    }
    @Bean PlatformTransactionManager transactionManager(DataSource ds) { return new DataSourceTransactionManager(ds); }
    @Bean JwtDecoder jwtDecoder() {
      return token -> {
        UUID id = switch (token) {
          case "test-admin" -> ADMIN;
          case "test-vaccinator" -> VACCINATOR;
          default -> throw new JwtException("Token de prueba desconocido");
        };
        return Jwt.withTokenValue(token).header("alg", "none").subject(id.toString())
            .issuedAt(Instant.now()).expiresAt(Instant.now().plusSeconds(600)).build();
      };
    }
    @Bean IdentityService identityService() {
      var identity = mock(IdentityService.class);
      var institution = mock(InstitutionEntity.class);
      when(institution.getId()).thenReturn(INST);
      when(identity.resolve(ADMIN)).thenReturn(new AuthorizedUser(ADMIN, "admin@test", "Admin prueba", institution,
          List.of("ADMIN_INSTITUTION"), List.of("INVENTORY_READ", "INVENTORY_WRITE", "CATALOG_CONFIG_READ", "USER_MANAGE"), Instant.now()));
      when(identity.resolve(VACCINATOR)).thenReturn(new AuthorizedUser(VACCINATOR, "vac@test", "Vacunador prueba", institution,
          List.of("VACCINATOR"), List.of("ATTENTION_CREATE"), Instant.now()));
      return identity;
    }
  }

  /** Solo los selectores usan catalogo/usuarios sinteticos; inventario usa controladores reales. */
  @RestController
  @RequestMapping("/api/v1")
  static class FixtureCatalog {
    @GetMapping("/institutions/{id}/vaccines")
    List<Map<String, Object>> vaccines(@PathVariable UUID id) {
      if (!INST.equals(id)) throw new IllegalArgumentException("Institucion invalida");
      return List.of(Map.of("vaccineId", VACCINE.toString(), "name", "Vacuna prueba", "enabled", true));
    }
    @GetMapping("/users")
    List<Map<String, Object>> users(@RequestParam UUID institutionId) {
      if (!INST.equals(institutionId)) throw new IllegalArgumentException("Institucion invalida");
      return List.of(Map.of("id", VACCINATOR.toString(), "fullName", "Vacunador prueba", "status", "ACTIVE", "roles", List.of("VACCINATOR")));
    }
  }

  @Test
  void widgetsExerciseEnabledApiAndTransactions() throws Exception {
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
      db.execute("CREATE TABLE app.inventory_lots (id UUID PRIMARY KEY, institution_id UUID, vaccine_id UUID, manufacturer VARCHAR, lot_number VARCHAR, expires_on DATE, doses_per_vial INT, available_vials INT DEFAULT 0 CHECK (available_vials >= 0), created_by UUID)");
      db.execute("CREATE TABLE app.inventory_assignments (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, vaccinator_id UUID, vial_count INT, status VARCHAR, dispatched_by UUID, dispatched_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, received_at TIMESTAMP WITH TIME ZONE, campaign_id UUID)");
      db.execute("CREATE TABLE app.inventory_campaigns (id UUID PRIMARY KEY, institution_id UUID, name VARCHAR, location VARCHAR, starts_on DATE, ends_on DATE, status VARCHAR, created_by UUID, finished_by UUID, finished_at TIMESTAMP WITH TIME ZONE)");
      db.execute("CREATE TABLE app.inventory_campaign_participants (institution_id UUID, campaign_id UUID, vaccinator_id UUID, added_by UUID, PRIMARY KEY(campaign_id, vaccinator_id))");
      db.execute("CREATE TABLE app.inventory_movements (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, assignment_id UUID, kind VARCHAR, vial_count INT, occurred_at TIMESTAMP WITH TIME ZONE, recorded_by UUID, note VARCHAR)");
      db.execute("CREATE TABLE app.inventory_custody_events (id UUID PRIMARY KEY, institution_id UUID, lot_id UUID, "
          + "assignment_id UUID, vial_count INT, status VARCHAR, reported_by UUID, report_note VARCHAR, "
          + "reported_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, confirmed_by UUID, "
          + "confirmed_at TIMESTAMP WITH TIME ZONE, confirmation_note VARCHAR)");
      db.execute("CREATE TABLE app.inventory_installation_reservations (id UUID PRIMARY KEY, institution_id UUID, "
          + "assignment_id UUID, vial_count INT)");
      UUID role = UUID.randomUUID();
      db.update("INSERT INTO app.vaccines VALUES (?, 'Vacuna prueba')", VACCINE);
      db.update("INSERT INTO app.users VALUES (?, ?, 'ACTIVE')", VACCINATOR, INST);
      db.update("INSERT INTO app.roles VALUES (?, 'VACCINATOR')", role);
      db.update("INSERT INTO app.user_roles VALUES (?, ?)", VACCINATOR, role);
      int port = ((WebServerApplicationContext) context).getWebServer().getPort();
      String date = java.time.LocalDate.now().toString();
      var request = java.net.http.HttpRequest.newBuilder(java.net.URI.create("http://127.0.0.1:" + port
              + "/api/v1/institutions/" + INST + "/inventory/campaigns"))
          .header("Authorization", "Bearer test-admin").header("Content-Type", "application/json")
          .POST(java.net.http.HttpRequest.BodyPublishers.ofString("{\"id\":\"" + CAMPAIGN
              + "\",\"name\":\"Jornada prueba\",\"location\":\"Centro prueba\",\"startsOn\":\""
              + date + "\",\"endsOn\":\"" + date + "\"}")) .build();
      var response = java.net.http.HttpClient.newHttpClient().send(request, java.net.http.HttpResponse.BodyHandlers.ofString());
      assertThat(response.statusCode()).as("Crear jornada mediante API habilitada: %s", response.body()).isEqualTo(201);

      Path app = Path.of("..", "..", "apps", "mobile").toAbsolutePath().normalize();
      var process = new ProcessBuilder("cmd", "/c", "flutter.bat", "test", "test/features/inventory/inventory_http_e2e_test.dart")
          .directory(app.toFile()).redirectErrorStream(true);
      process.environment().put("INVENTORY_E2E_URL", "http://127.0.0.1:" + port + "/api/v1");
      var flutter = process.start();
      var output = new StringBuilder();
      var reader = Thread.ofVirtual().start(() -> {
        try (var lines = flutter.inputReader()) { lines.lines().forEach(line -> output.append(line).append('\n')); }
        catch (java.io.IOException e) { output.append(e.getMessage()); }
      });
      assertThat(flutter.waitFor(120, TimeUnit.SECONDS)).as("La prueba Flutter debe finalizar").isTrue();
      reader.join();
      assertThat(flutter.exitValue()).as("Widgets con API real: %s", output).isZero();
      System.out.println("Flutter HTTP E2E: flujo completo verificado; " + output.toString().trim());
      assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots", Integer.class)).isEqualTo(9);
      assertThat(db.queryForObject("SELECT status FROM app.inventory_assignments", String.class)).isEqualTo("RECEIVED");
      assertThat(db.queryForObject("SELECT campaign_id FROM app.inventory_assignments", UUID.class)).isEqualTo(CAMPAIGN);
      assertThat(db.queryForObject("SELECT status FROM app.inventory_campaigns", String.class)).isEqualTo("FINISHED");
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_movements", Integer.class)).isEqualTo(3);
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_custody_events WHERE status IN ('RETURN_AVAILABLE','INCIDENT_LOST')", Integer.class)).isEqualTo(2);
      System.out.println("Móvil E2E: jornada=FINISHED; saldo=9; entrega=RECEIVED; devolución=RETURN_AVAILABLE");
      UUID event = db.queryForObject("SELECT id FROM app.inventory_custody_events WHERE status='RETURN_AVAILABLE'", UUID.class);
      String base = "http://127.0.0.1:" + port + "/api/v1/institutions/" + INST + "/inventory/custody-events";
      var unauthorized = java.net.http.HttpRequest.newBuilder(java.net.URI.create(base + "/" + event + "/confirm"))
          .header("Authorization", "Bearer test-vaccinator").header("Content-Type", "application/json")
          .POST(java.net.http.HttpRequest.BodyPublishers.ofString("{\"disposition\":\"AVAILABLE\",\"note\":\"Prueba\"}")).build();
      assertThat(java.net.http.HttpClient.newHttpClient().send(unauthorized, java.net.http.HttpResponse.BodyHandlers.ofString()).statusCode()).isEqualTo(403);
      assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots", Integer.class)).isEqualTo(9);
      System.out.println("Novedad movil: perdida registrada; saldo sin cambios; confirmacion no autorizada=403");
    }
  }
}
