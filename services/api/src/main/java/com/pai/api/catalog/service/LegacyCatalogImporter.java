package com.pai.api.catalog.service;

import java.io.InputStream;
import java.time.Instant;
import java.util.UUID;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineOptionTemplateEntity;
import com.pai.api.catalog.repository.VaccineOptionRepository;
import com.pai.api.catalog.repository.VaccineOptionTemplateRepository;
import com.pai.api.catalog.repository.VaccineRepository;

/** Imports the generated, checked-in projection of vaccine_seeder.dart. */
@Component
public class LegacyCatalogImporter implements ApplicationRunner {
    private static final UUID SYSTEM = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private final VaccineRepository vaccines;
    private final VaccineOptionRepository options;
    private final VaccineOptionTemplateRepository templates;
    private final ObjectMapper mapper;

    public LegacyCatalogImporter(VaccineRepository vaccines, VaccineOptionRepository options,
            VaccineOptionTemplateRepository templates, ObjectMapper mapper) {
        this.vaccines = vaccines;
        this.options = options;
        this.templates = templates;
        this.mapper = mapper;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) throws Exception {
        try (InputStream input = new ClassPathResource("catalog/legacy-vaccines.json").getInputStream()) {
            for (JsonNode row : mapper.readTree(input)) {
                boolean created = vaccines.findByCode(row.path("code").asText()).isEmpty();
                VaccineEntity vaccine = vaccines.findByCode(row.path("code").asText()).orElseGet(() ->
                    vaccines.save(new VaccineEntity(UUID.randomUUID(), row.path("name").asText(),
                        row.path("code").asText(), row.path("category").asText(),
                        (short) row.path("maxDoses").asInt(), nullableInt(row, "minMonths"),
                        nullableInt(row, "maxMonths"), SYSTEM, Instant.now())));
                JsonNode flags = row.path("flags");
                if (created) {
                    vaccine.setLegacyFlags(flags.get(0).asBoolean(), flags.get(1).asBoolean(),
                        flags.get(2).asBoolean(), flags.get(3).asBoolean(), flags.get(4).asBoolean(),
                        flags.get(5).asBoolean(), flags.get(6).asBoolean(), flags.get(7).asBoolean(),
                        flags.get(8).asBoolean());
                    vaccines.save(vaccine);
                }
                for (JsonNode group : row.path("options")) {
                    String type = group.path("fieldType").asText();
                    JsonNode values = group.path("values");
                    for (int index = 0; index < values.size(); index++) {
                        String display = values.get(index).asText();
                        String value = sanitize(display);
                        if (("dose".equals(type) || "pneumococcalType".equals(type))
                                && !options.existsByVaccineIdAndFieldTypeAndValueNormalizedAndActiveTrue(
                                    vaccine.getId(), type, value)) {
                            options.save(new VaccineOptionEntity(UUID.randomUUID(), vaccine.getId(), type,
                                value, display, index, index == 0, SYSTEM, Instant.now()));
                        } else if ("laboratory".equals(type) || "syringe".equals(type)
                                || "dropper".equals(type) || "observation".equals(type)) {
                            if (templates.existsByVaccineIdAndFieldTypeAndValueNormalizedAndActiveTrue(
                                    vaccine.getId(), type, value)) continue;
                            templates.save(new VaccineOptionTemplateEntity(UUID.randomUUID(), vaccine.getId(),
                                type, value, display, index, false, SYSTEM, Instant.now()));
                        }
                    }
                }
            }
        }
    }

    private static Integer nullableInt(JsonNode row, String field) {
        return row.get(field) == null || row.get(field).isNull() ? null : row.get(field).asInt();
    }

    private static String sanitize(String text) {
        return text.toLowerCase().replace(" ", "_").replace("(", "").replace(")", "")
            .replace(",", "").replace(".", "").replace("á", "a").replace("é", "e")
            .replace("í", "i").replace("ó", "o").replace("ú", "u").replace("ñ", "n");
    }
}
