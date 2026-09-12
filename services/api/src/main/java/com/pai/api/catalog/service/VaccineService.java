package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.*;
import com.pai.api.catalog.entity.*;
import com.pai.api.catalog.exception.OptimisticCatalogException;
import com.pai.api.catalog.repository.*;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.shared.security.PermissionGuard;
import java.time.Instant;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VaccineService {
    private final VaccineRepository vaccines;
    private final VaccineOptionRepository options;
    private final VaccineOptionTemplateRepository templates;
    private final PermissionGuard guard;

    public VaccineService(
            VaccineRepository v, VaccineOptionRepository o, VaccineOptionTemplateRepository t, PermissionGuard g) {
        vaccines = v;
        options = o;
        templates = t;
        guard = g;
    }

    @Transactional(readOnly = true)
    public List<VaccineResponse> list(UUID actor) {
        guard.require(actor, "CATALOG_GLOBAL_READ");
        return vaccines.findByActiveTrueOrderByNameAsc().stream().map(this::v).toList();
    }

    @Transactional
    public VaccineResponse create(UUID actor, VaccineRequest r) {
        AuthorizedUser a = guard.require(actor, "CATALOG_GLOBAL_WRITE");
        VaccineEntity x = new VaccineEntity(
                UUID.randomUUID(),
                r.name(),
                r.code().trim(),
                r.category(),
                r.maxDoses(),
                r.minAgeMonths(),
                r.maxAgeMonths(),
                a.getId(),
                Instant.now());
        x.setLegacyFlags(
                r.hasLaboratory(),
                r.hasLot(),
                r.hasSyringe(),
                r.hasSyringeLot(),
                r.hasDiluent(),
                r.hasDropper(),
                r.hasPneumococcalType(),
                r.hasVialCount(),
                r.hasObservation());
        return v(vaccines.save(x));
    }

    @Transactional
    public VaccineResponse update(UUID actor, UUID id, VaccineRequest r, long version) {
        AuthorizedUser a = guard.require(actor, "CATALOG_GLOBAL_WRITE");
        VaccineEntity x = vaccines.findById(id).orElseThrow(() -> new IllegalArgumentException("Vacuna no existe."));
        if (x.getVersion() != version)
            throw new OptimisticCatalogException("La vacuna fue modificada por otro usuario.");
        x.update(r.name(), r.category(), r.maxDoses(), r.minAgeMonths(), r.maxAgeMonths(), true, a.getId());
        x.setLegacyFlags(
                r.hasLaboratory(),
                r.hasLot(),
                r.hasSyringe(),
                r.hasSyringeLot(),
                r.hasDiluent(),
                r.hasDropper(),
                r.hasPneumococcalType(),
                r.hasVialCount(),
                r.hasObservation());
        return v(vaccines.save(x));
    }

    @Transactional
    public void delete(UUID actor, UUID id, long version) {
        AuthorizedUser a = guard.require(actor, "CATALOG_GLOBAL_WRITE");
        VaccineEntity x = vaccines.findById(id).orElseThrow(() -> new IllegalArgumentException("Vacuna no existe."));
        if (x.getVersion() != version)
            throw new OptimisticCatalogException("La vacuna fue modificada por otro usuario.");
        x.update(
                x.getName(),
                x.getCategory(),
                x.getMaxDoses(),
                x.getMinAgeMonths(),
                x.getMaxAgeMonths(),
                false,
                a.getId());
    }

    @Transactional(readOnly = true)
    public List<OptionResponse> globalOptions(UUID actor, UUID vaccine) {
        guard.require(actor, "CATALOG_GLOBAL_READ");
        return options.findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(vaccine).stream()
                .map(x -> o(x, null))
                .toList();
    }

    @Transactional
    public OptionResponse createOption(UUID actor, UUID vaccine, OptionRequest r) {
        AuthorizedUser a = guard.require(actor, "CATALOG_GLOBAL_WRITE");
        requireVaccine(vaccine);
        validateGlobalType(r.fieldType());
        requireValue(r.value());
        return o(
                options.save(new VaccineOptionEntity(
                        UUID.randomUUID(),
                        vaccine,
                        r.fieldType(),
                        r.value(),
                        r.displayName(),
                        r.sortOrder(),
                        r.isDefault(),
                        a.getId(),
                        Instant.now())),
                null);
    }

    @Transactional
    public OptionResponse updateOption(UUID actor, UUID vaccine, UUID id, OptionRequest r) {
        AuthorizedUser a = guard.require(actor, "CATALOG_GLOBAL_WRITE");
        requireVaccine(vaccine);
        validateGlobalType(r.fieldType());
        requireValue(r.value());
        VaccineOptionEntity x = options.findByIdAndVaccineId(id, vaccine)
                .orElseThrow(() -> new IllegalArgumentException("Opcion no existe."));
        if (!x.getFieldType().equals(r.fieldType()))
            throw new IllegalArgumentException("El tipo de opcion no puede cambiarse.");
        if (x.getVersion() != r.version())
            throw new OptimisticCatalogException("La opcion fue modificada por otro usuario.");
        if (r.isDefault())
            options.lockActive(vaccine).stream()
                    .filter(y -> y.getFieldType().equals(x.getFieldType())
                            && !y.getId().equals(id))
                    .forEach(y -> y.update(
                            y.getValue(), y.getDisplayName(), y.getSortOrder(), false, y.isActive(), a.getId()));
        x.update(r.value(), r.displayName(), r.sortOrder(), r.isDefault(), r.isActive(), a.getId());
        return o(options.save(x), null);
    }

    @Transactional
    public void deleteOption(UUID actor, UUID vaccine, UUID id, long version) {
        AuthorizedUser a = guard.require(actor, "CATALOG_GLOBAL_WRITE");
        VaccineOptionEntity x = options.findByIdAndVaccineId(id, vaccine)
                .orElseThrow(() -> new IllegalArgumentException("Opcion no existe."));
        if (x.getVersion() != version)
            throw new OptimisticCatalogException("La opcion fue modificada por otro usuario.");
        x.update(x.getValue(), x.getDisplayName(), x.getSortOrder(), false, false, a.getId());
    }

    @Transactional(readOnly = true)
    public List<OptionResponse> templates(UUID actor, UUID vaccine) {
        guard.require(actor, "CATALOG_GLOBAL_READ");
        requireVaccine(vaccine);
        return templates.findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(vaccine).stream()
                .map(this::t)
                .toList();
    }

    @Transactional
    public OptionResponse createTemplate(UUID actor, UUID vaccine, OptionRequest r) {
        AuthorizedUser a = guard.require(actor, "CATALOG_GLOBAL_WRITE");
        requireVaccine(vaccine);
        validateTemplateType(r.fieldType());
        requireValue(r.value());
        return t(templates.save(new VaccineOptionTemplateEntity(
                UUID.randomUUID(),
                vaccine,
                r.fieldType(),
                r.value(),
                r.displayName(),
                r.sortOrder(),
                r.isDefault(),
                a.getId(),
                Instant.now())));
    }

    @Transactional
    public OptionResponse updateTemplate(UUID actor, UUID vaccine, UUID id, OptionRequest r) {
        AuthorizedUser a = guard.require(actor, "CATALOG_GLOBAL_WRITE");
        requireVaccine(vaccine);
        validateTemplateType(r.fieldType());
        requireValue(r.value());
        VaccineOptionTemplateEntity x = templates
                .findByIdAndVaccineId(id, vaccine)
                .orElseThrow(() -> new IllegalArgumentException("Template no existe."));
        if (!x.getFieldType().equals(r.fieldType()))
            throw new IllegalArgumentException("El tipo de template no puede cambiarse.");
        if (x.getVersion() != r.version())
            throw new OptimisticCatalogException("El template fue modificado por otro usuario.");
        if (r.isDefault())
            templates.lockActive(vaccine).stream()
                    .filter(y -> y.getFieldType().equals(x.getFieldType())
                            && !y.getId().equals(id))
                    .forEach(y -> y.update(
                            y.getValue(), y.getDisplayName(), y.getSortOrder(), false, y.isActive(), a.getId()));
        x.update(r.value(), r.displayName(), r.sortOrder(), r.isDefault(), r.isActive(), a.getId());
        return t(templates.save(x));
    }

    @Transactional
    public void deleteTemplate(UUID actor, UUID vaccine, UUID id, long version) {
        AuthorizedUser a = guard.require(actor, "CATALOG_GLOBAL_WRITE");
        requireVaccine(vaccine);
        VaccineOptionTemplateEntity x = templates
                .findByIdAndVaccineId(id, vaccine)
                .orElseThrow(() -> new IllegalArgumentException("Template no existe."));
        if (x.getVersion() != version)
            throw new OptimisticCatalogException("El template fue modificado por otro usuario.");
        x.update(x.getValue(), x.getDisplayName(), x.getSortOrder(), false, false, a.getId());
    }

    private VaccineResponse v(VaccineEntity x) {
        return new VaccineResponse(
                x.getId(),
                x.getName(),
                x.getCode(),
                x.getCategory(),
                x.getMaxDoses(),
                x.getMinAgeMonths(),
                x.getMaxAgeMonths(),
                x.hasLaboratory(),
                x.hasLot(),
                x.hasSyringe(),
                x.hasSyringeLot(),
                x.hasDiluent(),
                x.hasDropper(),
                x.hasPneumococcalType(),
                x.hasVialCount(),
                x.hasObservation(),
                x.isActive(),
                x.getVersion());
    }

    private OptionResponse o(VaccineOptionEntity x, UUID i) {
        return new OptionResponse(
                x.getId(),
                x.getVaccineId(),
                i,
                x.getFieldType(),
                x.getValue(),
                x.getDisplayName(),
                x.getSortOrder(),
                x.isDefault(),
                x.isActive(),
                null,
                x.getVersion());
    }

    private OptionResponse t(VaccineOptionTemplateEntity x) {
        return new OptionResponse(
                x.getId(),
                x.getVaccineId(),
                null,
                x.getFieldType(),
                x.getValue(),
                x.getDisplayName(),
                x.getSortOrder(),
                x.isDefault(),
                x.isActive(),
                null,
                x.getVersion());
    }

    private void requireVaccine(UUID id) {
        if (!vaccines.existsById(id)) throw new IllegalArgumentException("Vacuna no existe.");
    }

    private void validateGlobalType(String type) {
        if (!Set.of("dose", "pneumococcalType").contains(type))
            throw new IllegalArgumentException("Tipo de opcion global invalido.");
    }

    private void validateTemplateType(String type) {
        if (!Set.of("laboratory", "syringe", "dropper", "observation").contains(type))
            throw new IllegalArgumentException("Tipo de template invalido.");
    }

    private void requireValue(String value) {
        if (value == null || value.trim().isEmpty())
            throw new IllegalArgumentException("El valor no puede estar vacio.");
    }
}
