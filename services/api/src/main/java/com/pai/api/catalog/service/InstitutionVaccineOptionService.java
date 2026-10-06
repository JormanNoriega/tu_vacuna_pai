package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.OptionRequest;
import com.pai.api.catalog.dto.OptionResponse;
import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineOptionTemplateEntity;
import com.pai.api.catalog.exception.OptimisticCatalogException;
import com.pai.api.catalog.repository.InstitutionVaccineOptionRepository;
import com.pai.api.catalog.repository.InstitutionVaccineRepository;
import com.pai.api.catalog.repository.VaccineOptionTemplateRepository;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.security.PermissionGuard;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Opciones operativas de una vacuna habilitada en la institucion (laboratorio,
 * jeringa, gotero, observacion) y su catalogo de sugerencias globales. Separado
 * de {@link InstitutionVaccineService} (relaciones/clone) por SRP.
 */
@Service
public class InstitutionVaccineOptionService {

  private final InstitutionVaccineOptionRepository local;
  private final InstitutionVaccineRepository relations;
  private final VaccineOptionTemplateRepository templates;
  private final DataScope scope;
  private final PermissionGuard guard;
  private final CatalogMapper mapper;

  public InstitutionVaccineOptionService(
      InstitutionVaccineOptionRepository local,
      InstitutionVaccineRepository relations,
      VaccineOptionTemplateRepository templates,
      DataScope scope,
      PermissionGuard guard,
      CatalogMapper mapper) {
    this.local = local;
    this.relations = relations;
    this.templates = templates;
    this.scope = scope;
    this.guard = guard;
    this.mapper = mapper;
  }

  @Transactional(readOnly = true)
  public List<OptionResponse> options(UUID actorId, UUID requestedInstitution, UUID vaccineId) {
    AuthorizedUser actor = guard.require(actorId, "CATALOG_CONFIG_READ");
    UUID institutionId = scope.resolveInstitutionId(actor, requestedInstitution);
    requireEnabled(institutionId, vaccineId);

    return local
        .findByInstitutionIdAndVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(
            institutionId, vaccineId)
        .stream()
        .map(option -> mapper.toInstitutionOption(option, vaccineId, institutionId))
        .toList();
  }

  @Transactional
  public OptionResponse createOption(
      UUID actorId, UUID requestedInstitution, UUID vaccineId, OptionRequest request) {
    AuthorizedUser actor = guard.require(actorId, "CATALOG_CONFIG_WRITE");
    UUID institutionId = scope.resolveInstitutionId(actor, requestedInstitution);
    requireEnabled(institutionId, vaccineId);
    CatalogRules.requireLocalOptionType(request.fieldType());

    if (request.isDefault()) {
      clearDefaults(institutionId, vaccineId, request.fieldType(), actor.getId());
    }

    InstitutionVaccineOptionEntity option = local.save(new InstitutionVaccineOptionEntity(
        UUID.randomUUID(),
        institutionId,
        vaccineId,
        request.fieldType(),
        request.value(),
        request.displayName(),
        request.sortOrder(),
        request.isDefault(),
        null,
        actor.getId(),
        Instant.now()));
    return mapper.toInstitutionOption(option, vaccineId, institutionId);
  }

  @Transactional
  public OptionResponse updateOption(
      UUID actorId,
      UUID requestedInstitution,
      UUID vaccineId,
      UUID optionId,
      OptionRequest request) {
    AuthorizedUser actor = guard.require(actorId, "CATALOG_CONFIG_WRITE");
    UUID institutionId = scope.resolveInstitutionId(actor, requestedInstitution);
    requireEnabled(institutionId, vaccineId);
    CatalogRules.requireLocalOptionType(request.fieldType());

    InstitutionVaccineOptionEntity option = local
        .findByIdAndInstitutionIdAndVaccineId(optionId, institutionId, vaccineId)
        .orElseThrow(() -> new IllegalArgumentException("Opcion local no existe."));
    if (option.getVersion() != request.version()) {
      throw new OptimisticCatalogException("La opcion fue modificada por otro usuario.");
    }
    if (request.isDefault()) {
      clearDefaults(institutionId, vaccineId, request.fieldType(), actor.getId(), optionId);
    }

    option.update(
        request.value(),
        request.displayName(),
        request.sortOrder(),
        request.isDefault(),
        request.isActive(),
        actor.getId());
    return mapper.toInstitutionOption(option, vaccineId, institutionId);
  }

  @Transactional
  public void deleteOption(
      UUID actorId, UUID requestedInstitution, UUID vaccineId, UUID optionId, long version) {
    AuthorizedUser actor = guard.require(actorId, "CATALOG_CONFIG_WRITE");
    UUID institutionId = scope.resolveInstitutionId(actor, requestedInstitution);
    requireEnabled(institutionId, vaccineId);

    InstitutionVaccineOptionEntity option = local
        .findByIdAndInstitutionIdAndVaccineId(optionId, institutionId, vaccineId)
        .orElseThrow(() -> new IllegalArgumentException("Opcion local no existe."));
    if (option.getVersion() != version) {
      throw new OptimisticCatalogException("La opcion fue modificada por otro usuario.");
    }
    option.update(
        option.getValue(),
        option.getDisplayName(),
        option.getSortOrder(),
        false,
        false,
        actor.getId());
  }

  @Transactional(readOnly = true)
  public List<OptionResponse> suggested(UUID actorId, UUID requestedInstitution, UUID vaccineId) {
    AuthorizedUser actor = guard.require(actorId, "CATALOG_CONFIG_READ");
    UUID institutionId = scope.resolveInstitutionId(actor, requestedInstitution);
    Set<String> existing = existingValues(institutionId, vaccineId);

    return templates
        .findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(vaccineId)
        .stream()
        .filter(template -> !existing.contains(template.getValueNormalized()))
        .map(template -> mapper.toSuggestedOption(template, vaccineId, institutionId))
        .toList();
  }

  @Transactional
  public List<OptionResponse> importSuggested(
      UUID actorId, UUID requestedInstitution, UUID vaccineId) {
    AuthorizedUser actor = guard.require(actorId, "CATALOG_CONFIG_WRITE");
    UUID institutionId = scope.resolveInstitutionId(actor, requestedInstitution);
    requireEnabled(institutionId, vaccineId);
    Set<String> existing = existingValues(institutionId, vaccineId);
    List<OptionResponse> imported = new ArrayList<>();

    for (VaccineOptionTemplateEntity template :
        templates.findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(vaccineId)) {
      if (!existing.add(template.getValueNormalized())) {
        continue;
      }
      try {
        InstitutionVaccineOptionEntity option =
            local.saveAndFlush(new InstitutionVaccineOptionEntity(
                UUID.randomUUID(),
                institutionId,
                vaccineId,
                template.getFieldType(),
                template.getValue(),
                template.getDisplayName(),
                template.getSortOrder(),
                false,
                template.getId(),
                actor.getId(),
                Instant.now()));
        imported.add(mapper.toInstitutionOption(option, vaccineId, institutionId));
      } catch (DataIntegrityViolationException ignored) {
        // Another request imported the same suggestion first.
      }
    }
    return imported;
  }

  private Set<String> existingValues(UUID institutionId, UUID vaccineId) {
    return new HashSet<>(local
        .findByInstitutionIdAndVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(
            institutionId, vaccineId)
        .stream()
        .map(InstitutionVaccineOptionEntity::getValueNormalized)
        .toList());
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
            option.getValue(),
            option.getDisplayName(),
            option.getSortOrder(),
            false,
            option.isActive(),
            actorId));
  }

  private void requireEnabled(UUID institutionId, UUID vaccineId) {
    if (relations
        .findByInstitutionIdAndVaccineId(institutionId, vaccineId)
        .filter(relation -> relation.isEnabled())
        .isEmpty()) {
      throw new IllegalArgumentException("La vacuna no esta habilitada en la institucion.");
    }
  }
}
