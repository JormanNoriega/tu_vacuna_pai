package com.pai.api.catalog.entity;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Verifica que el prototipo {@link VaccineOptionTemplateEntity} se clona en una
 * opcion institucional conservando los atributos y cambiando id/institucion. */
class VaccineOptionTemplateEntityPrototypeTest {

  @Test
  void copyToInstitution_clonesTemplateIntoInstitutionOption() {
    UUID templateId = UUID.randomUUID();
    UUID vaccineId = UUID.randomUUID();
    UUID institutionId = UUID.randomUUID();
    UUID actorId = UUID.randomUUID();

    VaccineOptionTemplateEntity template =
        new VaccineOptionTemplateEntity(
            templateId, vaccineId, "laboratory", "Pfizer", "Pfizer", 3, false, actorId, Instant.now());

    InstitutionVaccineOptionEntity copy = template.copyToInstitution(institutionId, actorId);

    assertThat(copy.getId()).isNotNull().isNotEqualTo(templateId);
    assertThat(copy.getInstitutionId()).isEqualTo(institutionId);
    assertThat(copy.getVaccineId()).isEqualTo(vaccineId);
    assertThat(copy.getFieldType()).isEqualTo("laboratory");
    assertThat(copy.getValue()).isEqualTo("Pfizer");
    assertThat(copy.getDisplayName()).isEqualTo("Pfizer");
    assertThat(copy.getSortOrder()).isEqualTo(3);
    assertThat(copy.isDefault()).isFalse();
    assertThat(copy.isActive()).isTrue();
    assertThat(copy.getSourceTemplateId()).isEqualTo(templateId);
  }
}
