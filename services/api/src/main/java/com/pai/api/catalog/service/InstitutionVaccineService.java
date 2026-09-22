package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.CloneCatalogResponse;
import com.pai.api.catalog.dto.InstitutionVaccineResponse;
import com.pai.api.catalog.dto.VaccineResponse;
import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionTemplateEntity;
import com.pai.api.catalog.repository.InstitutionVaccineOptionRepository;
import com.pai.api.catalog.repository.InstitutionVaccineRepository;
import com.pai.api.catalog.repository.VaccineOptionTemplateRepository;
import com.pai.api.catalog.repository.VaccineRepository;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.InstitutionCatalogSeeder;
import com.pai.api.shared.security.PermissionGuard;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Relacion vacuna{@literal <->}institucion: habilitar/deshabilitar, listar,
 * clonar el catalogo global y sembrarlo al crear una institucion. Las opciones
 * operativas de cada vacuna viven en
 * {@link InstitutionVaccineOptionService} (SRP).
 */
@Service
public class InstitutionVaccineService implements InstitutionCatalogSeeder {
  private final InstitutionVaccineRepository relations;
  private final InstitutionVaccineOptionRepository local;
  private final VaccineRepository vaccines;
  private final VaccineOptionTemplateRepository templates;
  private final DataScope scope;
  private final PermissionGuard guard;
  private final CatalogMapper mapper;

  public InstitutionVaccineService(
      InstitutionVaccineRepository relations,
      InstitutionVaccineOptionRepository local,
      VaccineRepository vaccines,
      VaccineOptionTemplateRepository templates,
      DataScope scope,
      PermissionGuard guard,
      CatalogMapper mapper) {
    this.relations = relations;
    this.local = local;
    this.vaccines = vaccines;
    this.templates = templates;
    this.scope = scope;
    this.guard = guard;
    this.mapper = mapper;
  }

  private UUID institution(AuthorizedUser actor, UUID requestedInstitution) {
    return scope.resolveInstitutionId(actor, requestedInstitution);
  }

  @Transactional(readOnly = true)
  public List<InstitutionVaccineResponse> list(UUID actorId, UUID requestedInstitution) {
    AuthorizedUser actor = guard.require(actorId, "CATALOG_CONFIG_READ");
    UUID institutionId = institution(actor, requestedInstitution);

    List<InstitutionVaccineEntity> relationList = relations.findByInstitutionId(institutionId);
    // Carga las vacunas en bloque (1 query) en lugar de un findById por relacion.
    Map<UUID, VaccineEntity> vaccinesById = vaccines
        .findAllById(relationList.stream()
            .map(InstitutionVaccineEntity::getVaccineId)
            .distinct()
            .toList())
        .stream()
        .collect(Collectors.toMap(VaccineEntity::getId, vaccine -> vaccine));

    return relationList.stream()
        .map(relation -> {
          VaccineEntity vaccine = vaccinesById.get(relation.getVaccineId());
          if (vaccine == null) {
            throw new IllegalArgumentException("Vacuna no existe.");
          }
          return mapper.toInstitutionVaccine(relation, vaccine, institutionId);
        })
        .toList();
  }

  @Transactional
  public void enable(UUID actorId, UUID requestedInstitution, UUID vaccineId) {
    AuthorizedUser actor = guard.require(actorId, "CATALOG_CONFIG_WRITE");
    UUID institutionId = institution(actor, requestedInstitution);
    VaccineEntity vaccine = vaccines
        .findById(vaccineId)
        .orElseThrow(() -> new IllegalArgumentException("Vacuna no existe."));
    if (!vaccine.isActive()) {
      throw new IllegalArgumentException("La vacuna esta inactiva.");
    }

    int inserted = relations.insertEnabledIfAbsent(institutionId, vaccineId, actor.getId());

    if (inserted > 0) {
      for (VaccineOptionTemplateEntity template :
          templates.findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(vaccineId)) {
        local.save(new InstitutionVaccineOptionEntity(
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
      }
      return;
    }

    relations
        .findByInstitutionIdAndVaccineId(institutionId, vaccineId)
        .filter(relation -> !relation.isEnabled())
        .ifPresent(relation -> relations.setEnabledById(relation.getId(), true));
  }

  @Transactional
  public void disable(UUID actorId, UUID requestedInstitution, UUID vaccineId) {
    AuthorizedUser actor = guard.require(actorId, "CATALOG_CONFIG_WRITE");
    UUID institutionId = institution(actor, requestedInstitution);
    relations
        .findByInstitutionIdAndVaccineId(institutionId, vaccineId)
        .ifPresent(relation -> relations.setEnabledById(relation.getId(), false));
  }

  /**
   * Clona el catalogo global hacia una institucion: habilita las vacunas
   * activas que aun no tienen relacion con la institucion y, cuando
   * [includeDefaultConfig] es true, copia las opciones operativas de los
   * templates como configuracion por defecto.
   *
   * <p>La operacion es copy-once e idempotente y respeta la autonomia de la
   * institucion: las vacunas con relacion existente (habilitadas o
   * deshabilitadas) nunca se tocan, por lo que el re-clone no pisa decisiones
   * locales. Las opciones locales existentes no se sobrescriben.
   */
  @Transactional
  public CloneCatalogResponse clone(
      UUID actorId, UUID requestedInstitution, boolean includeDefaultConfig) {
    AuthorizedUser actor = guard.require(actorId, "CATALOG_CONFIG_WRITE");
    UUID institutionId = institution(actor, requestedInstitution);
    return doClone(institutionId, actor.getId(), includeDefaultConfig);
  }

  /**
   * Siembra el catalogo global activo en una institucion como accion de
   * sistema (sin chequeo de permisos): al crear una institucion y en el
   * backfill de instituciones sin catalogo. Copy-once e idempotente.
   */
  @Override
  @Transactional
  public void seed(UUID institutionId, UUID actorId) {
    doClone(institutionId, actorId, true);
  }

  private CloneCatalogResponse doClone(
      UUID institutionId, UUID actorId, boolean includeDefaultConfig) {
    List<VaccineEntity> active = vaccines.findByActiveTrueOrderByNameAsc();
    int vaccinesEnabled = 0;
    int optionsCopied = 0;

    for (VaccineEntity vaccine : active) {
      int inserted = relations.insertEnabledIfAbsent(institutionId, vaccine.getId(), actorId);

      if (inserted == 0) {
        // La relacion ya existia (habilitada o deshabilitada): no se toca.
        continue;
      }

      vaccinesEnabled++;
      if (includeDefaultConfig) {
        for (VaccineOptionTemplateEntity template :
            templates.findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(
                vaccine.getId())) {
          local.save(new InstitutionVaccineOptionEntity(
              UUID.randomUUID(),
              institutionId,
              vaccine.getId(),
              template.getFieldType(),
              template.getValue(),
              template.getDisplayName(),
              template.getSortOrder(),
              false,
              template.getId(),
              actorId,
              Instant.now()));
          optionsCopied++;
        }
      }
    }
    return new CloneCatalogResponse(vaccinesEnabled, optionsCopied, active.size());
  }

  /**
   * Devuelve las vacunas activas del catalogo global que aun no tienen
   * relacion con la institucion, para que el ADMIN_INSTITUTION pueda
   * habilitarlas cuando lo decida. Las deshabilitadas en la institucion no
   * aparecen aqui: ya tienen relacion y su estado se respeta.
   */
  @Transactional(readOnly = true)
  public List<VaccineResponse> available(UUID actorId, UUID requestedInstitution) {
    AuthorizedUser actor = guard.require(actorId, "CATALOG_CONFIG_READ");
    UUID institutionId = institution(actor, requestedInstitution);

    Set<UUID> existing = relations.findByInstitutionId(institutionId).stream()
        .map(InstitutionVaccineEntity::getVaccineId)
        .collect(Collectors.toSet());

    return vaccines.findByActiveTrueOrderByNameAsc().stream()
        .filter(vaccine -> !existing.contains(vaccine.getId()))
        .map(mapper::toVaccine)
        .toList();
  }
}
