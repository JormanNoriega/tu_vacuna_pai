package com.pai.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.catalog.dto.InstitutionVaccineResponse;
import com.pai.api.catalog.dto.OptionResponse;
import com.pai.api.catalog.dto.VaccineResponse;
import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineOptionTemplateEntity;
import com.pai.api.catalog.service.CatalogMapper;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class CatalogMapperTest {

    private static final UUID ACTOR = UUID.randomUUID();
    private static final UUID INSTITUTION = UUID.randomUUID();
    private static final UUID VACCINE = UUID.randomUUID();
    private static final CatalogMapper mapper = new CatalogMapper();

    @Test
    void toVaccine_mapsAllFieldsIncludingLegacyFlags() {
        VaccineEntity entity = new VaccineEntity(
                VACCINE, "Influenza", "INF", "PAI", (short) 2, 6, 120, ACTOR, Instant.now());
        entity.setLegacyFlags(true, false, true, false, true, false, true, false, true);

        VaccineResponse response = mapper.toVaccine(entity);

        assertThat(response.id()).isEqualTo(VACCINE);
        assertThat(response.name()).isEqualTo("Influenza");
        assertThat(response.code()).isEqualTo("INF");
        assertThat(response.category()).isEqualTo("PAI");
        assertThat(response.maxDoses()).isEqualTo((short) 2);
        assertThat(response.minAgeMonths()).isEqualTo(6);
        assertThat(response.maxAgeMonths()).isEqualTo(120);
        assertThat(response.hasLaboratory()).isTrue();
        assertThat(response.hasLot()).isFalse();
        assertThat(response.hasSyringe()).isTrue();
        assertThat(response.hasSyringeLot()).isFalse();
        assertThat(response.hasDiluent()).isTrue();
        assertThat(response.hasDropper()).isFalse();
        assertThat(response.hasPneumococcalType()).isTrue();
        assertThat(response.hasVialCount()).isFalse();
        assertThat(response.hasObservation()).isTrue();
        assertThat(response.active()).isTrue();
    }

    @Test
    void toGlobalOption_mapsGlobalOptionWithoutInstitution() {
        OptionResponse response = mapper.toGlobalOption(optionEntity());

        assertThat(response.id()).isEqualTo(VACCINE);
        assertThat(response.vaccineId()).isEqualTo(VACCINE);
        assertThat(response.institutionId()).isNull();
        assertThat(response.fieldType()).isEqualTo("dose");
        assertThat(response.value()).isEqualTo("valor");
        assertThat(response.displayName()).isEqualTo("Dosis 1");
        assertThat(response.isActive()).isTrue();
        assertThat(response.sourceTemplateId()).isNull();
    }

    @Test
    void toInstitutionOption_preservesSourceTemplateIdAndScope() {
        InstitutionVaccineOptionEntity entity = new InstitutionVaccineOptionEntity(
                UUID.randomUUID(),
                INSTITUTION,
                VACCINE,
                "laboratory",
                "valor",
                "Pfizer",
                0,
                false,
                VACCINE,
                ACTOR,
                Instant.now());

        OptionResponse response = mapper.toInstitutionOption(entity, VACCINE, INSTITUTION);

        assertThat(response.institutionId()).isEqualTo(INSTITUTION);
        assertThat(response.sourceTemplateId()).isEqualTo(VACCINE);
        assertThat(response.fieldType()).isEqualTo("laboratory");
    }

    @Test
    void toSuggestedOption_marksSuggestionActiveWithZeroVersion() {
        UUID templateId = UUID.randomUUID();
        VaccineOptionTemplateEntity template = new VaccineOptionTemplateEntity(
                templateId, VACCINE, "laboratory", "valor", "Pfizer", 3, false, ACTOR, Instant.now());

        OptionResponse response = mapper.toSuggestedOption(template, VACCINE, INSTITUTION);

        assertThat(response.id()).isEqualTo(templateId);
        assertThat(response.institutionId()).isEqualTo(INSTITUTION);
        assertThat(response.isDefault()).isFalse();
        assertThat(response.isActive()).isTrue();
        assertThat(response.sourceTemplateId()).isEqualTo(templateId);
        assertThat(response.version()).isZero();
        assertThat(response.sortOrder()).isEqualTo(3);
    }

    @Test
    void toInstitutionVaccine_mapsRelationWithVaccineData() {
        InstitutionVaccineEntity relation = mock(InstitutionVaccineEntity.class);
        when(relation.getId()).thenReturn(UUID.randomUUID());
        when(relation.isEnabled()).thenReturn(true);
        when(relation.getVersion()).thenReturn(3L);
        VaccineEntity vaccine = new VaccineEntity(
                VACCINE, "Polio", "POL", "PAI", (short) 3, null, null, ACTOR, Instant.now());

        InstitutionVaccineResponse response =
                mapper.toInstitutionVaccine(relation, vaccine, INSTITUTION);

        assertThat(response.institutionId()).isEqualTo(INSTITUTION);
        assertThat(response.vaccineId()).isEqualTo(VACCINE);
        assertThat(response.name()).isEqualTo("Polio");
        assertThat(response.code()).isEqualTo("POL");
        assertThat(response.enabled()).isTrue();
        assertThat(response.version()).isEqualTo(3L);
    }

    private VaccineOptionEntity optionEntity() {
        return new VaccineOptionEntity(
                VACCINE, VACCINE, "dose", "valor", "Dosis 1", 0, true, ACTOR, Instant.now());
    }
}