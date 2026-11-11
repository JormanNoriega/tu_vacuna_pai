package com.pai.api.inventory;

import static org.assertj.core.api.Assertions.assertThat;

import com.pai.api.ApiApplication;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.LocalDate;
import java.util.Properties;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.support.BeanDefinitionRegistry;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.server.context.WebServerApplicationContext;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.ObjectMapper;

/** Opt-in: identidades, institucion y registros efimeros en el proyecto autorizado. */
@EnabledIfEnvironmentVariable(named = "INVENTORY_RUN_SUPABASE_MOBILE_E2E", matches = "true")
class InventorySupabaseMobileE2eTest {
  private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(20)).build();
  private final ObjectMapper json = new ObjectMapper();

  @Test
  void widgetsUseRealSupabaseJwtAndPostgres() throws Exception {
    Properties settings = new Properties();
    try (var reader = Files.newBufferedReader(Path.of(".env.local"))) { settings.load(reader); }
    String marker = System.getenv("INVENTORY_EXPECTED_DB_MARKER");
    String dbUser = settings.getProperty("DB_USERNAME");
    assertThat(marker).isNotBlank();
    assertThat(dbUser != null && dbUser.endsWith("." + marker)).isTrue();
    String issuer = settings.getProperty("SUPABASE_AUTH_ISSUER");
    assertThat(issuer != null && issuer.startsWith("https://" + marker + ".supabase.co/auth/v1"))
        .as("El emisor y la base deben pertenecer al proyecto autorizado").isTrue();
    String serviceKey = settings.getProperty("SUPABASE_SERVICE_ROLE_KEY");
    assertThat(serviceKey).as("Clave de servicio configurada localmente").isNotBlank();
    var source = new DriverManagerDataSource(settings.getProperty("DB_URL"), dbUser, settings.getProperty("DB_PASSWORD"));
    var db = new JdbcTemplate(source);
    var tx = new TransactionTemplate(new DataSourceTransactionManager(source));
    UUID institution = UUID.randomUUID();
    String code = "E2E-" + institution.toString().substring(0, 8);
    String adminEmail = "inventario-" + institution + "-admin@example.com";
    String vaccinatorEmail = "inventario-" + institution + "-vac@example.com";
    String password = "Test-" + UUID.randomUUID() + "-aA1!";
    UUID admin = null;
    UUID vaccinator = null;
    try {
      admin = createUser(issuer, serviceKey, adminEmail, password);
      vaccinator = createUser(issuer, serviceKey, vaccinatorEmail, password);
      UUID adminId = admin;
      UUID vaccinatorId = vaccinator;
      var vaccine = db.queryForMap("SELECT id, name FROM app.vaccines WHERE is_active = true ORDER BY name LIMIT 1");
      UUID vaccineId = (UUID) vaccine.get("id");
      String vaccineName = (String) vaccine.get("name");
      tx.executeWithoutResult(status -> {
        db.update("INSERT INTO app.institutions (id, code, name) VALUES (?, ?, 'INVENTARIO E2E TEMPORAL')", institution, code);
        db.update("INSERT INTO app.users (id, email, full_name, institution_id) VALUES (?, ?, 'Admin prueba', ?)", adminId, adminEmail, institution);
        db.update("INSERT INTO app.users (id, email, full_name, institution_id) VALUES (?, ?, 'Vacunador prueba', ?)", vaccinatorId, vaccinatorEmail, institution);
        db.update("INSERT INTO app.user_roles (user_id, role_id) SELECT ?, id FROM app.roles WHERE code='ADMIN_INSTITUTION'", adminId);
        db.update("INSERT INTO app.user_roles (user_id, role_id) SELECT ?, id FROM app.roles WHERE code='VACCINATOR'", vaccinatorId);
        db.update("INSERT INTO app.institution_vaccines (institution_id, vaccine_id, is_enabled) VALUES (?, ?, true)", institution, vaccineId);
      });
      String adminToken = signIn(issuer, serviceKey, adminEmail, password);
      String vaccinatorToken = signIn(issuer, serviceKey, vaccinatorEmail, password);

      // No ejecutar sembradores globales durante una prueba de inventario.
      try (var context = new SpringApplicationBuilder(ApiApplication.class)
          .initializers(ctx -> ctx.addBeanFactoryPostProcessor(factory -> {
            var registry = (BeanDefinitionRegistry) factory;
            for (String name : ListOfSeeders.NAMES) {
              if (registry.containsBeanDefinition(name)) registry.removeBeanDefinition(name);
            }
          }))
          .run("--server.port=0", "--app.inventory.api-enabled=true", "--app.inventory.reservations-enabled=true",
              "--app.inventory.installation-keys-enabled=true", "--spring.flyway.enabled=false")) {
        int port = ((WebServerApplicationContext) context).getWebServer().getPort();
        String base = "http://127.0.0.1:" + port + "/api/v1";
        UUID installation = UUID.randomUUID();
        String inventory = base + "/institutions/" + institution + "/inventory";
        var registration = send("POST", inventory + "/installations", vaccinatorToken, null,
            json.writeValueAsString(java.util.Map.of("id", installation.toString(), "label", "Equipo temporal")));
        assertThat(registration.statusCode()).as("Registro temporal").isEqualTo(201);
        String keyBase = inventory + "/installations/" + installation + "/key";
        var keyPair = java.security.KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
        String encodedKey = java.util.Base64.getEncoder().encodeToString(keyPair.getPublic().getEncoded());
        String keyBody = json.writeValueAsString(java.util.Map.of("publicKey", encodedKey));
        assertThat(send("POST", keyBase + "/challenges", null, null, keyBody).statusCode()).isEqualTo(401);
        var issued = send("POST", keyBase + "/challenges", vaccinatorToken, null, keyBody);
        assertThat(issued.statusCode()).as("Desafio con JWT Supabase").isEqualTo(200);
        var challengeJson = json.readTree(issued.body());
        UUID challengeId = UUID.fromString(challengeJson.get("id").asString());
        byte[] nonce = java.util.Base64.getDecoder().decode(challengeJson.get("nonce").asString());
        var signer = java.security.Signature.getInstance("Ed25519");
        signer.initSign(keyPair.getPrivate());
        signer.update(com.pai.api.inventory.security.InstallationProof.message(institution, vaccinatorId, installation, nonce));
        String signature = java.util.Base64.getEncoder().encodeToString(signer.sign());
        String confirm = json.writeValueAsString(java.util.Map.of("challengeId", challengeId.toString(), "publicKey", encodedKey, "signature", signature));
        assertThat(send("POST", keyBase + "/confirm", vaccinatorToken, null, confirm).statusCode()).isEqualTo(204);
        String revoke = json.writeValueAsString(java.util.Map.of("note", "Prueba autorizacion"));
        assertThat(send("POST", keyBase + "/revoke", vaccinatorToken, null, revoke).statusCode()).isEqualTo(403);
        assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_keys WHERE installation_id=?", String.class, installation)).isEqualTo("ACTIVE");
        assertThat(send("POST", keyBase + "/revoke", adminToken, null, revoke).statusCode()).isEqualTo(204);
        assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_keys WHERE installation_id=?", String.class, installation)).isEqualTo("REVOKED");
        System.out.println("JWT real: acceso anonimo=401; alta firmada=204; revocacion vacunador=403; administrador=204");
        UUID campaign = UUID.randomUUID();
        var campaignBody = json.writeValueAsString(java.util.Map.of("id", campaign.toString(), "name", "Jornada prueba",
            "location", "Centro prueba", "startsOn", LocalDate.now().toString(), "endsOn", LocalDate.now().toString()));
        var response = send("POST", base + "/institutions/" + institution + "/inventory/campaigns", adminToken, null, campaignBody);
        assertThat(response.statusCode()).as("Creacion de jornada con JWT Supabase real").isEqualTo(201);
        Path app = Path.of("..", "..", "apps", "mobile").toAbsolutePath().normalize();
        var builder = new ProcessBuilder("cmd", "/c", "flutter.bat", "test", "test/features/inventory/inventory_http_e2e_test.dart")
            .directory(app.toFile()).redirectErrorStream(true);
        builder.environment().put("INVENTORY_E2E_URL", base);
        builder.environment().put("INVENTORY_E2E_INSTITUTION", institution.toString());
        builder.environment().put("INVENTORY_E2E_VACCINE_NAME", vaccineName);
        builder.environment().put("INVENTORY_E2E_ADMIN_TOKEN", adminToken);
        builder.environment().put("INVENTORY_E2E_VACCINATOR_TOKEN", vaccinatorToken);
        var process = builder.start();
        var output = new StringBuilder();
        var reader = Thread.ofVirtual().start(() -> {
          try (var lines = process.inputReader()) { lines.lines().forEach(line -> output.append(line).append('\n')); }
          catch (java.io.IOException e) { output.append("No se pudo leer la salida de Flutter."); }
        });
        if (!process.waitFor(240, TimeUnit.SECONDS)) {
          process.destroyForcibly();
          throw new AssertionError("La prueba Flutter excedio el tiempo permitido.");
        }
        reader.join();
        assertThat(process.exitValue()).as("Flutter contra Supabase: %s", output).isZero();
        assertThat(db.queryForObject("SELECT available_vials FROM app.inventory_lots WHERE institution_id=?", Integer.class, institution)).isEqualTo(9);
        assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_custody_events WHERE institution_id=? AND status IN ('RETURN_AVAILABLE','INCIDENT_LOST')", Integer.class, institution)).isEqualTo(2);
        System.out.println("Supabase Auth + PostgreSQL + widgets Flutter: saldo=9; devolucion confirmada y perdida registrada; OK");
      }
    } finally {
      // Solo datos de la institucion creada por esta ejecucion, nunca los datos existentes.
      Integer owned = db.queryForObject("SELECT count(*) FROM app.institutions WHERE id=? AND code=?", Integer.class, institution, code);
      if (owned != null && owned == 1) {
        tx.executeWithoutResult(status -> {
          db.update("DELETE FROM app.inventory_installation_recovery_cases WHERE institution_id=?", institution);
          db.update("DELETE FROM app.inventory_installation_reservations WHERE institution_id=?", institution);
          db.update("DELETE FROM app.inventory_installation_keys WHERE institution_id=?", institution);
          db.update("DELETE FROM app.inventory_installation_proof_challenges WHERE institution_id=?", institution);
          db.update("DELETE FROM app.inventory_installations WHERE institution_id=?", institution);
          db.update("DELETE FROM app.inventory_custody_events WHERE institution_id=?", institution);
          db.update("DELETE FROM app.inventory_movements WHERE institution_id=?", institution);
          db.update("DELETE FROM app.inventory_assignments WHERE institution_id=?", institution);
          db.update("DELETE FROM app.inventory_campaign_participants WHERE institution_id=?", institution);
          db.update("DELETE FROM app.inventory_campaigns WHERE institution_id=?", institution);
          db.update("DELETE FROM app.inventory_lots WHERE institution_id=?", institution);
          db.update("DELETE FROM app.institution_vaccines WHERE institution_id=?", institution);
          db.update("DELETE FROM app.user_roles WHERE user_id IN (SELECT id FROM app.users WHERE institution_id=?)", institution);
          db.update("DELETE FROM app.users WHERE institution_id=?", institution);
          db.update("DELETE FROM app.institutions WHERE id=? AND code=?", institution, code);
        });
      }
      if (admin != null) deleteUser(issuer, serviceKey, admin);
      if (vaccinator != null) deleteUser(issuer, serviceKey, vaccinator);
    }
  }

  private UUID createUser(String issuer, String key, String email, String password) throws Exception {
    String body = json.writeValueAsString(java.util.Map.of("email", email, "password", password, "email_confirm", true));
    var response = send("POST", issuer + "/admin/users", key, key, body);
    assertThat(response.statusCode()).as("Provisionar identidad temporal").isBetween(200, 299);
    return UUID.fromString(json.readTree(response.body()).get("id").asString());
  }

  private String signIn(String issuer, String key, String email, String password) throws Exception {
    String body = json.writeValueAsString(java.util.Map.of("email", email, "password", password));
    var response = send("POST", issuer + "/token?grant_type=password", null, key, body);
    assertThat(response.statusCode()).as("Inicio de sesion Supabase temporal").isEqualTo(200);
    return json.readTree(response.body()).get("access_token").asString();
  }

  private void deleteUser(String issuer, String key, UUID user) throws Exception {
    var response = send("DELETE", issuer + "/admin/users/" + user, key, key, null);
    assertThat(response.statusCode()).as("Eliminar identidad temporal").isBetween(200, 299);
  }

  private HttpResponse<String> send(String method, String url, String bearer, String apiKey, String body) throws Exception {
    var request = HttpRequest.newBuilder(URI.create(url)).timeout(Duration.ofSeconds(30));
    if (bearer != null) request.header("Authorization", "Bearer " + bearer);
    if (apiKey != null) request.header("apikey", apiKey);
    if (body != null) request.header("Content-Type", "application/json");
    return http.send(request.method(method, body == null ? HttpRequest.BodyPublishers.noBody()
        : HttpRequest.BodyPublishers.ofString(body)).build(), HttpResponse.BodyHandlers.ofString());
  }

  private static final class ListOfSeeders {
    static final String[] NAMES = {"legacyCatalogImporter", "geoCatalogImporter", "healthInsurerImporter"};
  }
}
