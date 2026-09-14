package com.pai.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Set;
import org.junit.jupiter.api.Test;

class LegacyCatalogResourceTest {
  private static final Set<String> ALLOWED_TYPES =
      Set.of("dose", "pneumococcalType", "laboratory", "syringe", "dropper", "observation");

  @Test
  void generatedProjectionContainsAllLegacyVaccinesAndMappedOptions() throws Exception {
    try (InputStream input =
        getClass().getClassLoader().getResourceAsStream("catalog/legacy-vaccines.json")) {
      String json = new String(input.readAllBytes(), StandardCharsets.UTF_8);
      assertThat(json.split("\\\"code\\\"\\s*:", -1)).hasSize(28);
      assertThat(json)
          .contains(
              "COVID-19",
              "covid19",
              "todas",
              "DPT (Difteria, Tos ferina, Tétanos)",
              "Meningococo (Serogrupos A, C, W-135, Y)");
      assertThat(json.split("\\\"flags\\\"\\s*:", -1)).hasSize(28);
      assertThat(json).contains("true");
      assertThat(json.split("\\\"fieldType\\\"\\s*:", -1)).hasSize(62);
      for (String type : ALLOWED_TYPES) assertThat(json).contains(type);
    }
  }
}
