package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.*;
import com.pai.api.catalog.entity.*;
import com.pai.api.catalog.exception.OptimisticCatalogException;
import com.pai.api.catalog.repository.*;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.shared.security.PermissionGuard;
import java.time.Instant;
import java.util.*;
import java.util.function.Consumer;
import java.util.function.Function;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VaccineService {
  private final VaccineRepository vaccines;
  private final VaccineOptionRepository options;
  private final VaccineOptionTemplateRepository templates;
  private final PermissionGuard guard;
  private final CatalogMapper mapper;

  public VaccineService(
      VaccineRepository v,
      VaccineOptionRepository o,
      VaccineOptionTemplateRepository t,
      PermissionGuard g,
      CatalogMapper m) {
    vaccines = v;
    options = o;
    templates = t;
    guard = g;
    mapper = m;
  }

  @Transactional(readOnly = true)
  public List<VaccineResponse> list(UUID actor) {
    guard.require(actor, "CATALOG_GLOBAL_READ");
    return vaccines.findByActiveTrueOrderByNameAsc().stream()
        .map(mapper::toVaccine)
        .toList();
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
    return mapper.toVaccine(vaccines.save(x));
  }

  @Transactional
  public VaccineResponse update(UUID actor, UUID id, VaccineRequest r, long version) {
    AuthorizedUser a = guard.require(actor, "CATALOG_GLOBAL_WRITE");
    VaccineEntity x =
        vaccines.findById(id).orElseThrow(() -> new IllegalArgumentException("Vacuna no existe."));
    if (x.getVersion() != version)
      throw new OptimisticCatalogException("La vacuna fue modificada por otro usuario.");
    x.update(
        r.name(), r.category(), r.maxDoses(), r.minAgeMonths(), r.maxAgeMonths(), true, a.getId());
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
    return mapper.toVaccine(vaccines.save(x));
  }

  @Transactional
  public void delete(UUID actor, UUID id, long version) {
    AuthorizedUser a = guard.require(actor, "CATALOG_GLOBAL_WRITE");
    VaccineEntity x =
        vaccines.findById(id).orElseThrow(() -> new IllegalArgumentException("Vacuna no existe."));
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
        .map(mapper::toGlobalOption)
        .toList();
  }

  @Transactional
  public OptionResponse createOption(UUID actor, UUID vaccine, OptionRequest r) {
    return create(optionKind(), actor, vaccine, r);
  }

  @Transactional
  public OptionResponse createTemplate(UUID actor, UUID vaccine, OptionRequest r) {
    return create(templateKind(), actor, vaccine, r);
  }

  @Transactional
  public OptionResponse updateOption(UUID actor, UUID vaccine, UUID id, OptionRequest r) {
    return update(optionKind(), actor, vaccine, id, r);
  }

  @Transactional
  public OptionResponse updateTemplate(UUID actor, UUID vaccine, UUID id, OptionRequest r) {
    return update(templateKind(), actor, vaccine, id, r);
  }

  @Transactional
  public void deleteOption(UUID actor, UUID vaccine, UUID id, long version) {
    delete(optionKind(), actor, vaccine, id, version);
  }

  @Transactional
  public void deleteTemplate(UUID actor, UUID vaccine, UUID id, long version) {
    delete(templateKind(), actor, vaccine, id, version);
  }

  @Transactional(readOnly = true)
  public List<OptionResponse> templates(UUID actor, UUID vaccine) {
    guard.require(actor, "CATALOG_GLOBAL_READ");
    requireVaccine(vaccine);
    return templates.findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(vaccine).stream()
        .map(mapper::toTemplate)
        .toList();
  }

  // ---------- CRUD compartido de opciones/templates ----------

  /**
   * Estrategia que parametriza el CRUD comun de las opciones del catalogo
   * global (opciones vs templates): repositorio, mapeo, validacion de tipo,
   * mensajes y fabrica de entidad. Agregar un tipo nuevo no toca el algoritmo.
   */
  private record OptionKind<E extends CatalogOption>(
      CatalogOptionRepository<E> repository,
      Function<E, E> save,
      Function<E, OptionResponse> toResponse,
      Consumer<String> requireFieldType,
      OptionMessages messages,
      EntityFactory<E> factory) {}

  private record OptionMessages(String notFound, String typeImmutable, String conflict) {}

  @FunctionalInterface
  private interface EntityFactory<E> {
    E create(UUID vaccineId, OptionRequest request, UUID actorId);
  }

  private OptionKind<VaccineOptionEntity> optionKind() {
    return new OptionKind<>(
        options,
        options::save,
        mapper::toGlobalOption,
        CatalogRules::requireGlobalOptionType,
        new OptionMessages(
            "Opcion no existe.",
            "El tipo de opcion no puede cambiarse.",
            "La opcion fue modificada por otro usuario."),
        (vaccineId, r, actorId) -> new VaccineOptionEntity(
            UUID.randomUUID(),
            vaccineId,
            r.fieldType(),
            r.value(),
            r.displayName(),
            r.sortOrder(),
            r.isDefault(),
            actorId,
            Instant.now()));
  }

  private OptionKind<VaccineOptionTemplateEntity> templateKind() {
    return new OptionKind<>(
        templates,
        templates::save,
        mapper::toTemplate,
        CatalogRules::requireTemplateType,
        new OptionMessages(
            "Template no existe.",
            "El tipo de template no puede cambiarse.",
            "El template fue modificado por otro usuario."),
        (vaccineId, r, actorId) -> new VaccineOptionTemplateEntity(
            UUID.randomUUID(),
            vaccineId,
            r.fieldType(),
            r.value(),
            r.displayName(),
            r.sortOrder(),
            r.isDefault(),
            actorId,
            Instant.now()));
  }

  private <E extends CatalogOption> OptionResponse create(
      OptionKind<E> kind, UUID actorId, UUID vaccine, OptionRequest r) {
    AuthorizedUser a = guard.require(actorId, "CATALOG_GLOBAL_WRITE");
    requireVaccine(vaccine);
    kind.requireFieldType().accept(r.fieldType());
    CatalogRules.requireValue(r.value());
    return kind.toResponse().apply(kind.save().apply(kind.factory().create(vaccine, r, a.getId())));
  }

  private <E extends CatalogOption> OptionResponse update(
      OptionKind<E> kind, UUID actorId, UUID vaccine, UUID id, OptionRequest r) {
    AuthorizedUser a = guard.require(actorId, "CATALOG_GLOBAL_WRITE");
    requireVaccine(vaccine);
    kind.requireFieldType().accept(r.fieldType());
    CatalogRules.requireValue(r.value());
    E entity = kind.repository()
        .findByIdAndVaccineId(id, vaccine)
        .orElseThrow(() -> new IllegalArgumentException(kind.messages().notFound()));
    if (!entity.getFieldType().equals(r.fieldType())) {
      throw new IllegalArgumentException(kind.messages().typeImmutable());
    }
    if (entity.getVersion() != r.version()) {
      throw new OptimisticCatalogException(kind.messages().conflict());
    }
    if (r.isDefault()) {
      kind.repository().lockActive(vaccine).stream()
          .filter(
              y -> y.getFieldType().equals(entity.getFieldType()) && !y.getId().equals(id))
          .forEach(y -> y.update(
              y.getValue(), y.getDisplayName(), y.getSortOrder(), false, y.isActive(), a.getId()));
    }
    entity.update(
        r.value(), r.displayName(), r.sortOrder(), r.isDefault(), r.isActive(), a.getId());
    return kind.toResponse().apply(kind.save().apply(entity));
  }

  private <E extends CatalogOption> void delete(
      OptionKind<E> kind, UUID actorId, UUID vaccine, UUID id, long version) {
    AuthorizedUser a = guard.require(actorId, "CATALOG_GLOBAL_WRITE");
    requireVaccine(vaccine);
    E entity = kind.repository()
        .findByIdAndVaccineId(id, vaccine)
        .orElseThrow(() -> new IllegalArgumentException(kind.messages().notFound()));
    if (entity.getVersion() != version) {
      throw new OptimisticCatalogException(kind.messages().conflict());
    }
    entity.update(
        entity.getValue(), entity.getDisplayName(), entity.getSortOrder(), false, false, a.getId());
  }

  private void requireVaccine(UUID id) {
    if (!vaccines.existsById(id)) throw new IllegalArgumentException("Vacuna no existe.");
  }
}
