package com.pai.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.pai.api.catalog.dto.EffectiveCatalogResponse;
import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionEntity;
import com.pai.api.catalog.repository.InstitutionVaccineOptionRepository;
import com.pai.api.catalog.repository.InstitutionVaccineRepository;
import com.pai.api.catalog.repository.VaccineOptionRepository;
import com.pai.api.catalog.repository.VaccineRepository;
import com.pai.api.catalog.service.EffectiveCatalogService;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;

class EffectiveCatalogServiceTest {

    private static final UUID ACTOR_ID = UUID.randomUUID();
    private static final UUID INSTITUTION_ID = UUID.randomUUID();

    private InstitutionVaccineRepository institutionVaccines;
    private InstitutionVaccineOptionRepository institutionOptions;
    private VaccineRepository vaccines;
    private VaccineOptionRepository vaccineOptions;
    private IdentityService identity;
    private EffectiveCatalogService service;

    @BeforeEach
    void setUp() {
        institutionVaccines = mock(InstitutionVaccineRepository.class);
        institutionOptions = mock(InstitutionVaccineOptionRepository.class);
        vaccines = mock(VaccineRepository.class);
        vaccineOptions = mock(VaccineOptionRepository.class);
        identity = mock(IdentityService.class);
        service = new EffectiveCatalogService(institutionVaccines, institutionOptions,
            vaccines, vaccineOptions, identity, new DataScope());
    }

    private InstitutionEntity institution() {
        return new InstitutionEntity(INSTITUTION_ID, "HOSP-A", "Hospital A",
            InstitutionEntity.Status.ACTIVE, (short) 72, Instant.now(), Instant.now());
    }

    private AuthorizedUser actor() {
        return new AuthorizedUser(ACTOR_ID, "vac@hosp.a", "Ana Vacunadora",
            institution(), List.of("VACCINATOR"),
            List.of("CATALOG_GLOBAL_READ", "CATALOG_CONFIG_READ"), Instant.now());
    }

    @Test
    void list_includesEnabledVaccineWithDosesAndOperationalOptions() {
        UUID vaccineId = UUID.randomUUID();
        when(identity.resolve(ACTOR_ID)).thenReturn(actor());

        InstitutionVaccineEntity enabled = mock(InstitutionVaccineEntity.class);
        when(enabled.isEnabled()).thenReturn(true);
        when(enabled.getVaccineId()).thenReturn(vaccineId);
        when(institutionVaccines.findByInstitutionId(INSTITUTION_ID))
            .thenReturn(List.of(enabled));

        VaccineEntity vaccine = new VaccineEntity(vaccineId, "Influenza", "INF", "PAI",
            (short) 1, null, null, ACTOR_ID, Instant.now());
        when(vaccines.findById(vaccineId)).thenReturn(Optional.of(vaccine));

        UUID doseId = UUID.randomUUID();
        when(vaccineOptions.findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(
            vaccineId)).thenReturn(List.of(
                new VaccineOptionEntity(doseId, vaccineId, "dose", "1",
                    "Primera dosis", 0, true, ACTOR_ID, Instant.now())));
        UUID labId = UUID.randomUUID();
        when(institutionOptions
            .findByInstitutionIdAndVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(
                INSTITUTION_ID, vaccineId))
            .thenReturn(List.of(new InstitutionVaccineOptionEntity(labId, INSTITUTION_ID,
                vaccineId, "laboratory", "Pfizer", "Pfizer", 0, false, null, ACTOR_ID,
                Instant.now())));

        EffectiveCatalogResponse response = service.list(ACTOR_ID);

        assertThat(response.vaccines()).hasSize(1);
        EffectiveCatalogResponse.EffectiveVaccine effective = response.vaccines().get(0);
        assertThat(effective.name()).isEqualTo("Influenza");
        assertThat(effective.doses()).hasSize(1);
        assertThat(effective.doses().get(0).displayName()).isEqualTo("Primera dosis");
        assertThat(effective.operationalOptions()).hasSize(1);
        assertThat(effective.operationalOptions().get(0).displayName()).isEqualTo("Pfizer");
    }

    @Test
    void list_excludesDisabledVaccines() {
        when(identity.resolve(ACTOR_ID)).thenReturn(actor());
        InstitutionVaccineEntity disabled = mock(InstitutionVaccineEntity.class);
        when(disabled.isEnabled()).thenReturn(false);
        when(institutionVaccines.findByInstitutionId(INSTITUTION_ID))
            .thenReturn(List.of(disabled));

        EffectiveCatalogResponse response = service.list(ACTOR_ID);

        assertThat(response.vaccines()).isEmpty();
    }
}
