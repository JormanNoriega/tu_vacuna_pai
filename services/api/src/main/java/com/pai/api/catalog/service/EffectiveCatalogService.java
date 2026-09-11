package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.EffectiveCatalogResponse;
import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionEntity;
import com.pai.api.catalog.repository.InstitutionVaccineOptionRepository;
import com.pai.api.catalog.repository.InstitutionVaccineRepository;
import com.pai.api.catalog.repository.VaccineOptionRepository;
import com.pai.api.catalog.repository.VaccineRepository;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Catalogo efectivo de la institucion del actor. Combina:
 * <pre>
 * Vaccine.is_active = true
 * AND InstitutionVaccine.enabled = true
 * </pre>
 * con las dosis y tipos de neumococo globales ({@code vaccine_options}) y las
 * opciones operativas institucionales ({@code institution_vaccine_options}).
 */
@Service
public class EffectiveCatalogService {

    private static final String FIELD_DOSE = "dose";
    private static final String FIELD_PNEUMOCOCCAL = "pneumococcalType";

    private final InstitutionVaccineRepository institutionVaccines;
    private final InstitutionVaccineOptionRepository institutionOptions;
    private final VaccineRepository vaccines;
    private final VaccineOptionRepository vaccineOptions;
    private final IdentityService identity;
    private final DataScope dataScope;

    public EffectiveCatalogService(
            InstitutionVaccineRepository institutionVaccines,
            InstitutionVaccineOptionRepository institutionOptions,
            VaccineRepository vaccines,
            VaccineOptionRepository vaccineOptions,
            IdentityService identity,
            DataScope dataScope) {
        this.institutionVaccines = institutionVaccines;
        this.institutionOptions = institutionOptions;
        this.vaccines = vaccines;
        this.vaccineOptions = vaccineOptions;
        this.identity = identity;
        this.dataScope = dataScope;
    }

    @Transactional(readOnly = true)
    public EffectiveCatalogResponse list(UUID actorId) {
        AuthorizedUser actor = identity.resolve(actorId);
        UUID institutionId =
                dataScope.resolveInstitutionId(actor, actor.getInstitution().getId());

        // Relaciones habilitadas de la institucion (1 query).
        List<UUID> enabledVaccineIds = institutionVaccines.findByInstitutionId(institutionId).stream()
                .filter(InstitutionVaccineEntity::isEnabled)
                .map(InstitutionVaccineEntity::getVaccineId)
                .distinct()
                .toList();
        if (enabledVaccineIds.isEmpty()) {
            return new EffectiveCatalogResponse(List.of());
        }

        // Vacunas activas en bloque (1 query): evita el N+1 de findById por relacion.
        Map<UUID, VaccineEntity> vaccinesById = vaccines.findAllById(enabledVaccineIds).stream()
                .filter(VaccineEntity::isActive)
                .collect(Collectors.toMap(VaccineEntity::getId, vaccine -> vaccine));
        if (vaccinesById.isEmpty()) {
            return new EffectiveCatalogResponse(List.of());
        }

        // Dosis y tipos de neumococo globales en bloque (1 query).
        Map<UUID, List<VaccineOptionEntity>> dosesByVaccine = new HashMap<>();
        Map<UUID, List<VaccineOptionEntity>> pneumoByVaccine = new HashMap<>();
        for (VaccineOptionEntity option :
                vaccineOptions.findByVaccineIdInAndActiveTrueOrderByVaccineIdAscSortOrderAscDisplayNameAsc(
                        vaccinesById.keySet())) {
            if (FIELD_DOSE.equals(option.getFieldType())) {
                dosesByVaccine
                        .computeIfAbsent(option.getVaccineId(), key -> new ArrayList<>())
                        .add(option);
            } else if (FIELD_PNEUMOCOCCAL.equals(option.getFieldType())) {
                pneumoByVaccine
                        .computeIfAbsent(option.getVaccineId(), key -> new ArrayList<>())
                        .add(option);
            }
        }

        // Opciones operativas institucionales en bloque (1 query).
        Map<UUID, List<InstitutionVaccineOptionEntity>> operationalByVaccine = new LinkedHashMap<>();
        for (InstitutionVaccineOptionEntity option :
                institutionOptions
                        .findByInstitutionIdAndVaccineIdInAndActiveTrueOrderByVaccineIdAscSortOrderAscDisplayNameAsc(
                                institutionId, vaccinesById.keySet())) {
            operationalByVaccine
                    .computeIfAbsent(option.getVaccineId(), key -> new ArrayList<>())
                    .add(option);
        }

        List<EffectiveCatalogResponse.EffectiveVaccine> result = new ArrayList<>();
        for (UUID vaccineId : enabledVaccineIds) {
            VaccineEntity vaccine = vaccinesById.get(vaccineId);
            if (vaccine == null) {
                continue;
            }
            result.add(toEffectiveVaccine(
                    vaccine,
                    dosesByVaccine.getOrDefault(vaccineId, List.of()),
                    pneumoByVaccine.getOrDefault(vaccineId, List.of()),
                    operationalByVaccine.getOrDefault(vaccineId, List.of())));
        }
        return new EffectiveCatalogResponse(result);
    }

    private EffectiveCatalogResponse.EffectiveVaccine toEffectiveVaccine(
            VaccineEntity vaccine,
            List<VaccineOptionEntity> doses,
            List<VaccineOptionEntity> pneumo,
            List<InstitutionVaccineOptionEntity> operational) {
        List<EffectiveCatalogResponse.OptionItem> doseItems = new ArrayList<>();
        for (VaccineOptionEntity option : doses) {
            doseItems.add(toItem(
                    option.getId(),
                    option.getFieldType(),
                    option.getValue(),
                    option.getDisplayName(),
                    option.getSortOrder(),
                    option.isDefault()));
        }

        List<EffectiveCatalogResponse.OptionItem> pneumoItems = new ArrayList<>();
        for (VaccineOptionEntity option : pneumo) {
            pneumoItems.add(toItem(
                    option.getId(),
                    option.getFieldType(),
                    option.getValue(),
                    option.getDisplayName(),
                    option.getSortOrder(),
                    option.isDefault()));
        }

        List<EffectiveCatalogResponse.OptionItem> operationalItems = new ArrayList<>();
        for (InstitutionVaccineOptionEntity option : operational) {
            operationalItems.add(toItem(
                    option.getId(),
                    option.getFieldType(),
                    option.getValue(),
                    option.getDisplayName(),
                    option.getSortOrder(),
                    option.isDefault()));
        }

        return new EffectiveCatalogResponse.EffectiveVaccine(
                vaccine.getId(),
                vaccine.getName(),
                vaccine.getCode(),
                vaccine.getCategory(),
                vaccine.getMaxDoses(),
                vaccine.getMinAgeMonths(),
                vaccine.getMaxAgeMonths(),
                vaccine.getVersion(),
                vaccine.hasLaboratory(),
                vaccine.hasLot(),
                vaccine.hasSyringe(),
                vaccine.hasSyringeLot(),
                vaccine.hasDiluent(),
                vaccine.hasDropper(),
                vaccine.hasPneumococcalType(),
                vaccine.hasVialCount(),
                vaccine.hasObservation(),
                doseItems,
                pneumoItems,
                operationalItems);
    }

    private EffectiveCatalogResponse.OptionItem toItem(
            UUID id, String fieldType, String value, String displayName, int sortOrder, boolean isDefault) {
        return new EffectiveCatalogResponse.OptionItem(id, fieldType, value, displayName, sortOrder, isDefault);
    }
}
