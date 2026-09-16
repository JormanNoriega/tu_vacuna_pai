package com.pai.api.catalog.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pai.api.catalog.entity.HealthInsurerEntity;
import com.pai.api.catalog.repository.HealthInsurerRepository;
import java.io.InputStream;
import java.time.Instant;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Siembra el catalogo de aseguradoras (EPS) desde
 * {@code catalog/health_insurers.json}. Es idempotente y no destructivo: crea
 * las EPS que faltan por {@code nit} y actualiza solo los campos que cambiaron;
 * nunca reactiva una fila desactivada manualmente ({@code is_active}).
 *
 * <p>Mismo patron que {@link GeoCatalogImporter} para los catalogos globales: el
 * seed versionado vive en un recurso y se aplica con un importador, no con
 * cientos de INSERT en la migracion.
 */
@Component
public class HealthInsurerImporter implements ApplicationRunner {

  private static final String RESOURCE = "catalog/health_insurers.json";
  private static final Logger log = LoggerFactory.getLogger(HealthInsurerImporter.class);

  private final HealthInsurerRepository repository;
  private final ObjectMapper mapper = new ObjectMapper();

  public HealthInsurerImporter(HealthInsurerRepository repository) {
    this.repository = repository;
  }

  @Override
  @Transactional
  public void run(ApplicationArguments args) throws Exception {
    Instant now = Instant.now();
    int created = 0;
    int updated = 0;
    int unchanged = 0;

    try (InputStream input = new ClassPathResource(RESOURCE).getInputStream()) {
      for (JsonNode node : mapper.readTree(input)) {
        String nit = node.path("nit").asText();
        if (nit.isBlank()) {
          continue;
        }
        String name = node.path("name").asText();
        String code = textOrNull(node, "code");
        String mobilityCode = textOrNull(node, "mobilityCode");
        String regime = node.path("regime").asText();

        var existing = repository.findByNit(nit);
        if (existing.isEmpty()) {
          repository.save(new HealthInsurerEntity(
              UUID.randomUUID(), nit, name, code, mobilityCode, regime, true, now, now));
          created++;
        } else if (existing.get().applySeed(name, code, mobilityCode, regime, now)) {
          repository.save(existing.get());
          updated++;
        } else {
          unchanged++;
        }
      }
    }

    log.info(
        "Health insurer catalog seeded from {}: {} created, {} updated, {} unchanged",
        RESOURCE,
        created,
        updated,
        unchanged);
  }

  private static String textOrNull(JsonNode node, String field) {
    JsonNode value = node.path(field);
    if (value.isMissingNode() || value.isNull()) {
      return null;
    }
    String text = value.asText();
    return text.isBlank() ? null : text;
  }
}
