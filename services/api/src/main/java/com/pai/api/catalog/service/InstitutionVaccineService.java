package com.pai.api.catalog.service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import jakarta.persistence.EntityManager;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pai.api.catalog.dto.CloneCatalogResponse;
import com.pai.api.catalog.dto.OptionRequest;
import com.pai.api.catalog.dto.OptionResponse;
import com.pai.api.catalog.dto.InstitutionVaccineResponse;
import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionTemplateEntity;
import com.pai.api.catalog.exception.OptimisticCatalogException;
import com.pai.api.catalog.repository.InstitutionVaccineOptionRepository;
import com.pai.api.catalog.repository.InstitutionVaccineRepository;
import com.pai.api.catalog.repository.VaccineOptionTemplateRepository;
import com.pai.api.catalog.repository.VaccineRepository;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.shared.exceptions.PermissionDeniedException;

@Service
public class InstitutionVaccineService {
    private static final Set<String> LOCAL_OPTION_TYPES =
            Set.of("laboratory", "syringe", "dropper", "observation");

    private final InstitutionVaccineRepository relations;
    private final InstitutionVaccineOptionRepository local;
    private final VaccineRepository vaccines;
    private final VaccineOptionTemplateRepository templates;
    private final IdentityService identity;
    private final DataScope scope;
    private final EntityManager entityManager;

    public InstitutionVaccineService(
            InstitutionVaccineRepository relations,
            InstitutionVaccineOptionRepository local,
            VaccineRepository vaccines,
            VaccineOptionTemplateRepository templates,
            IdentityService identity,
            DataScope scope,
            EntityManager entityManager) {
        this.relations = relations;
        this.local = local;
        this.vaccines = vaccines;
        this.templates = templates;
        this.identity = identity;
        this.scope = scope;
        this.entityManager = entityManager;
    }

    private AuthorizedUser actor(UUID actorId, String permission) {
        AuthorizedUser actor = identity.resolve(actorId);
        if (!actor.getPermissions().contains(permission)) {
            throw new PermissionDeniedException("Permiso insuficiente: " + permission);
        }
        return actor;
    }

    private UUID institution(AuthorizedUser actor, UUID requestedInstitution) {
        return scope.resolveInstitutionId(actor, requestedInstitution);
    }

    @Transactional(readOnly = true)
    public List<InstitutionVaccineResponse> list(UUID actorId, UUID requestedInstitution) {
        AuthorizedUser actor = actor(actorId, "CATALOG_CONFIG_READ");
        UUID institutionId = institution(actor, requestedInstitution);

        return relations.findByInstitutionId(institutionId).stream()
                .map(relation -> {
                    VaccineEntity vaccine = vaccines.findById(relation.getVaccineId())
                            .orElseThrow(() -> new IllegalArgumentException("Vacuna no existe."));
                    return new InstitutionVaccineResponse(
                            relation.getId(), institutionId, vaccine.getId(), vaccine.getName(),
                            vaccine.getCode(), vaccine.getCategory(), relation.isEnabled(),
                            relation.getVersion());
                })
                .toList();
    }

    @Transactional
    public void enable(UUID actorId, UUID requestedInstitution, UUID vaccineId) {
        AuthorizedUser actor = actor(actorId, "CATALOG_CONFIG_WRITE");
        UUID institutionId = institution(actor, requestedInstitution);
        VaccineEntity vaccine = vaccines.findById(vaccineId)
                .orElseThrow(() -> new IllegalArgumentException("Vacuna no existe."));
        if (!vaccine.isActive()) {
            throw new IllegalArgumentException("La vacuna esta inactiva.");
        }

        List<?> inserted = entityManager.createNativeQuery(
                        "INSERT INTO app.institution_vaccines "
                                + "(institution_id, vaccine_id, is_enabled, enabled_at, enabled_by) "
                                + "VALUES (:institution, :vaccine, true, now(), :actor) "
                                + "ON CONFLICT (institution_id, vaccine_id) DO NOTHING RETURNING id")
                .setParameter("institution", institutionId)
                .setParameter("vaccine", vaccineId)
                .setParameter("actor", actor.getId())
                .getResultList();

        if (!inserted.isEmpty()) {
            for (VaccineOptionTemplateEntity template : templates
                    .findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(vaccineId)) {
                local.save(new InstitutionVaccineOptionEntity(
                        UUID.randomUUID(), institutionId, vaccineId, template.getFieldType(),
                        template.getValue(), template.getDisplayName(), template.getSortOrder(),
                        false, template.getId(), actor.getId(), Instant.now()));
            }
            return;
        }

        relations.findByInstitutionIdAndVaccineId(institutionId, vaccineId)
                .filter(relation -> !relation.isEnabled())
                .ifPresent(relation -> entityManager.createQuery(
                                "update InstitutionVaccineEntity relation "
                                        + "set relation.enabled = true where relation.id = :id")
                        .setParameter("id", relation.getId())
                        .executeUpdate());
    }

    @Transactional
    public void disable(UUID actorId, UUID requestedInstitution, UUID vaccineId) {
        AuthorizedUser actor = actor(actorId, "CATALOG_CONFIG_WRITE");
        UUID institutionId = institution(actor, requestedInstitution);
        relations.findByInstitutionIdAndVaccineId(institutionId, vaccineId)
                .ifPresent(relation -> entityManager.createQuery(
                                "update InstitutionVaccineEntity relation "
                                        + "set relation.enabled = false where relation.id = :id")
                        .setParameter("id", relation.getId())
                        .executeUpdate());
    }

    /**
     * Clona el catalogo global hacia una institucion: habilita todas las vacunas
     * activas (crea la relacion si no existe y reactiva las deshabilitadas) y,
     * cuando [includeDefaultConfig] es true, copia las opciones operativas de los
     * templates como configuracion por defecto. La copia es copy-once e
     * idempotente: las vacunas ya habilitadas no se tocan y las opciones locales
     * existentes no se sobrescriben.
     */
    @Transactional
    public CloneCatalogResponse clone(
            UUID actorId, UUID requestedInstitution, boolean includeDefaultConfig) {
        AuthorizedUser actor = actor(actorId, "CATALOG_CONFIG_WRITE");
        UUID institutionId = institution(actor, requestedInstitution);
        List<VaccineEntity> active = vaccines.findByActiveTrueOrderByNameAsc();
        int vaccinesEnabled = 0;
        int optionsCopied = 0;

        for (VaccineEntity vaccine : active) {
            List<?> inserted = entityManager.createNativeQuery(
                            "INSERT INTO app.institution_vaccines "
                                    + "(institution_id, vaccine_id, is_enabled, enabled_at, enabled_by) "
                                    + "VALUES (:institution, :vaccine, true, now(), :actor) "
                                    + "ON CONFLICT (institution_id, vaccine_id) DO NOTHING RETURNING id")
                    .setParameter("institution", institutionId)
                    .setParameter("vaccine", vaccine.getId())
                    .setParameter("actor", actor.getId())
                    .getResultList();

            if (!inserted.isEmpty()) {
                vaccinesEnabled++;
                if (includeDefaultConfig) {
                    for (VaccineOptionTemplateEntity template : templates
                            .findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(
                                    vaccine.getId())) {
                        local.save(new InstitutionVaccineOptionEntity(
                                UUID.randomUUID(), institutionId, vaccine.getId(),
                                template.getFieldType(), template.getValue(), template.getDisplayName(),
                                template.getSortOrder(), false, template.getId(), actor.getId(),
                                Instant.now()));
                        optionsCopied++;
                    }
                }
            } else {
                // La relacion ya existia: se reactiva si estaba deshabilitada, sin
                // volver a copiar opciones (misma regla que el enable explicito).
                relations.findByInstitutionIdAndVaccineId(institutionId, vaccine.getId())
                        .filter(relation -> !relation.isEnabled())
                        .ifPresent(relation -> entityManager.createQuery(
                                        "update InstitutionVaccineEntity relation "
                                                + "set relation.enabled = true where relation.id = :id")
                                .setParameter("id", relation.getId())
                                .executeUpdate());
            }
        }
        return new CloneCatalogResponse(vaccinesEnabled, optionsCopied, active.size());
    }

    @Transactional(readOnly = true)
    public List<OptionResponse> options(UUID actorId, UUID requestedInstitution, UUID vaccineId) {
        AuthorizedUser actor = actor(actorId, "CATALOG_CONFIG_READ");
        UUID institutionId = institution(actor, requestedInstitution);
        requireEnabled(institutionId, vaccineId);

        return local.findByInstitutionIdAndVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(
                        institutionId, vaccineId)
                .stream()
                .map(option -> toResponse(option, vaccineId, institutionId))
                .toList();
    }

    @Transactional
    public OptionResponse createOption(
            UUID actorId, UUID requestedInstitution, UUID vaccineId, OptionRequest request) {
        AuthorizedUser actor = actor(actorId, "CATALOG_CONFIG_WRITE");
        UUID institutionId = institution(actor, requestedInstitution);
        requireEnabled(institutionId, vaccineId);
        validateType(request.fieldType());

        if (request.isDefault()) {
            clearDefaults(institutionId, vaccineId, request.fieldType(), actor.getId());
        }

        InstitutionVaccineOptionEntity option = local.save(new InstitutionVaccineOptionEntity(
                UUID.randomUUID(), institutionId, vaccineId, request.fieldType(), request.value(),
                request.displayName(), request.sortOrder(), request.isDefault(), null, actor.getId(),
                Instant.now()));
        return toResponse(option, vaccineId, institutionId);
    }

    @Transactional
    public OptionResponse updateOption(
            UUID actorId,
            UUID requestedInstitution,
            UUID vaccineId,
            UUID optionId,
            OptionRequest request) {
        AuthorizedUser actor = actor(actorId, "CATALOG_CONFIG_WRITE");
        UUID institutionId = institution(actor, requestedInstitution);
        requireEnabled(institutionId, vaccineId);
        validateType(request.fieldType());

        InstitutionVaccineOptionEntity option = local
                .findByIdAndInstitutionIdAndVaccineId(optionId, institutionId, vaccineId)
                .orElseThrow(() -> new IllegalArgumentException("Opcion local no existe."));
        if (option.getVersion() != request.version()) {
            throw new OptimisticCatalogException(
                    "La opcion fue modificada por otro usuario.");
        }
        if (request.isDefault()) {
            clearDefaults(institutionId, vaccineId, request.fieldType(), actor.getId(), optionId);
        }

        option.update(request.value(), request.displayName(), request.sortOrder(),
                request.isDefault(), request.isActive(), actor.getId());
        return toResponse(option, vaccineId, institutionId);
    }

    @Transactional
    public void deleteOption(
            UUID actorId,
            UUID requestedInstitution,
            UUID vaccineId,
            UUID optionId,
            long version) {
        AuthorizedUser actor = actor(actorId, "CATALOG_CONFIG_WRITE");
        UUID institutionId = institution(actor, requestedInstitution);
        requireEnabled(institutionId, vaccineId);

        InstitutionVaccineOptionEntity option = local
                .findByIdAndInstitutionIdAndVaccineId(optionId, institutionId, vaccineId)
                .orElseThrow(() -> new IllegalArgumentException("Opcion local no existe."));
        if (option.getVersion() != version) {
            throw new OptimisticCatalogException(
                    "La opcion fue modificada por otro usuario.");
        }
        option.update(option.getValue(), option.getDisplayName(), option.getSortOrder(),
                false, false, actor.getId());
    }

    @Transactional(readOnly = true)
    public List<OptionResponse> suggested(UUID actorId, UUID requestedInstitution, UUID vaccineId) {
        AuthorizedUser actor = actor(actorId, "CATALOG_CONFIG_READ");
        UUID institutionId = institution(actor, requestedInstitution);
        Set<String> existing = new HashSet<>(local
                .findByInstitutionIdAndVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(
                        institutionId, vaccineId)
                .stream()
                .map(option -> option.getValueNormalized())
                .toList());

        return templates.findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(vaccineId)
                .stream()
                .filter(template -> !existing.contains(template.getValueNormalized()))
                .map(template -> new OptionResponse(
                        template.getId(), vaccineId, institutionId, template.getFieldType(),
                        template.getValue(), template.getDisplayName(), template.getSortOrder(),
                        false, true, template.getId(), 0))
                .toList();
    }

    @Transactional
    public List<OptionResponse> importSuggested(
            UUID actorId, UUID requestedInstitution, UUID vaccineId) {
        AuthorizedUser actor = actor(actorId, "CATALOG_CONFIG_WRITE");
        UUID institutionId = institution(actor, requestedInstitution);
        requireEnabled(institutionId, vaccineId);
        Set<String> existing = new HashSet<>(local
                .findByInstitutionIdAndVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(
                        institutionId, vaccineId)
                .stream()
                .map(option -> option.getValueNormalized())
                .toList());
        List<OptionResponse> imported = new ArrayList<>();

        for (VaccineOptionTemplateEntity template : templates
                .findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(vaccineId)) {
            if (!existing.add(template.getValueNormalized())) {
                continue;
            }
            try {
                InstitutionVaccineOptionEntity option = local.saveAndFlush(
                        new InstitutionVaccineOptionEntity(
                                UUID.randomUUID(), institutionId, vaccineId, template.getFieldType(),
                                template.getValue(), template.getDisplayName(), template.getSortOrder(),
                                false, template.getId(), actor.getId(), Instant.now()));
                imported.add(toResponse(option, vaccineId, institutionId));
            } catch (DataIntegrityViolationException ignored) {
                // Another request imported the same suggestion first.
            }
        }
        return imported;
    }

    private void clearDefaults(UUID institutionId, UUID vaccineId, String fieldType, UUID actorId) {
        clearDefaults(institutionId, vaccineId, fieldType, actorId, null);
    }

    private void clearDefaults(
            UUID institutionId, UUID vaccineId, String fieldType, UUID actorId, UUID exceptId) {
        local.lockActive(institutionId, vaccineId).stream()
                .filter(option -> option.getFieldType().equals(fieldType))
                .filter(option -> exceptId == null || !option.getId().equals(exceptId))
                .forEach(option -> option.update(
                        option.getValue(), option.getDisplayName(), option.getSortOrder(),
                        false, option.isActive(), actorId));
    }

    private OptionResponse toResponse(
            InstitutionVaccineOptionEntity option, UUID vaccineId, UUID institutionId) {
        return new OptionResponse(
                option.getId(), vaccineId, institutionId, option.getFieldType(), option.getValue(),
                option.getDisplayName(), option.getSortOrder(), option.isDefault(), option.isActive(),
                option.getSourceTemplateId(), option.getVersion());
    }

    private void validateType(String fieldType) {
        if (!LOCAL_OPTION_TYPES.contains(fieldType)) {
            throw new IllegalArgumentException("Tipo de opcion local invalido.");
        }
    }

    private void requireEnabled(UUID institutionId, UUID vaccineId) {
        if (relations.findByInstitutionIdAndVaccineId(institutionId, vaccineId)
                .filter(relation -> relation.isEnabled())
                .isEmpty()) {
            throw new IllegalArgumentException(
                    "La vacuna no esta habilitada en la institucion.");
        }
    }
}
