package com.pai.api.catalog.service;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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
        UUID institutionId = dataScope.resolveInstitutionId(
            actor, actor.getInstitution().getId());

        List<EffectiveCatalogResponse.EffectiveVaccine> result = new ArrayList<>();
        for (InstitutionVaccineEntity relation
                : institutionVaccines.findByInstitutionId(institutionId)) {
            if (!relation.isEnabled()) {
                continue;
            }
            VaccineEntity vaccine = vaccines.findById(relation.getVaccineId()).orElse(null);
            if (vaccine == null || !vaccine.isActive()) {
                continue;
            }
            result.add(toEffectiveVaccine(institutionId, vaccine));
        }
        return new EffectiveCatalogResponse(result);
    }

    private EffectiveCatalogResponse.EffectiveVaccine toEffectiveVaccine(
            UUID institutionId, VaccineEntity vaccine) {
        List<EffectiveCatalogResponse.OptionItem> doses = new ArrayList<>();
        List<EffectiveCatalogResponse.OptionItem> pneumo = new ArrayList<>();
        for (VaccineOptionEntity option : vaccineOptions
                .findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(
                    vaccine.getId())) {
            if (FIELD_DOSE.equals(option.getFieldType())) {
                doses.add(toItem(option.getId(), option.getFieldType(), option.getValue(),
                    option.getDisplayName(), option.getSortOrder(), option.isDefault()));
            } else if (FIELD_PNEUMOCOCCAL.equals(option.getFieldType())) {
                pneumo.add(toItem(option.getId(), option.getFieldType(), option.getValue(),
                    option.getDisplayName(), option.getSortOrder(), option.isDefault()));
            }
        }

        List<EffectiveCatalogResponse.OptionItem> operational = new ArrayList<>();
        for (InstitutionVaccineOptionEntity option : institutionOptions
                .findByInstitutionIdAndVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(
                    institutionId, vaccine.getId())) {
            operational.add(toItem(option.getId(), option.getFieldType(), option.getValue(),
                option.getDisplayName(), option.getSortOrder(), option.isDefault()));
        }

        return new EffectiveCatalogResponse.EffectiveVaccine(
            vaccine.getId(), vaccine.getName(), vaccine.getCode(), vaccine.getCategory(),
            vaccine.getMaxDoses(), vaccine.getMinAgeMonths(), vaccine.getMaxAgeMonths(),
            vaccine.getVersion(), vaccine.hasLaboratory(), vaccine.hasLot(),
            vaccine.hasSyringe(), vaccine.hasSyringeLot(), vaccine.hasDiluent(),
            vaccine.hasDropper(), vaccine.hasPneumococcalType(), vaccine.hasVialCount(),
            vaccine.hasObservation(), doses, pneumo, operational);
    }

    private EffectiveCatalogResponse.OptionItem toItem(UUID id, String fieldType,
            String value, String displayName, int sortOrder, boolean isDefault) {
        return new EffectiveCatalogResponse.OptionItem(
            id, fieldType, value, displayName, sortOrder, isDefault);
    }
}
