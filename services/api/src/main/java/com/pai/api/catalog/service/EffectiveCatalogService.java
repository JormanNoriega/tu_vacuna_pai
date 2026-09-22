package com.pai.api.catalog.service;

import com.pai.api.catalog.CatalogFieldType;
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
 * opciones operativas institucionales ({@code institution_vaccine_options}). El
 * ensamblado del DTO se delega en {@link CatalogMapper} (SRP).
 */
@Service
public class EffectiveCatalogService {

  private final InstitutionVaccineRepository institutionVaccines;
  private final InstitutionVaccineOptionRepository institutionOptions;
  private final VaccineRepository vaccines;
  private final VaccineOptionRepository vaccineOptions;
  private final IdentityService identity;
  private final DataScope dataScope;
  private final CatalogMapper mapper;

  public EffectiveCatalogService(
      InstitutionVaccineRepository institutionVaccines,
      InstitutionVaccineOptionRepository institutionOptions,
      VaccineRepository vaccines,
      VaccineOptionRepository vaccineOptions,
      IdentityService identity,
      DataScope dataScope,
      CatalogMapper mapper) {
    this.institutionVaccines = institutionVaccines;
    this.institutionOptions = institutionOptions;
    this.vaccines = vaccines;
    this.vaccineOptions = vaccineOptions;
    this.identity = identity;
    this.dataScope = dataScope;
    this.mapper = mapper;
  }

  @Transactional(readOnly = true)
  public EffectiveCatalogResponse list(UUID actorId) {
    AuthorizedUser actor = identity.resolve(actorId);
    UUID institutionId = dataScope.institutionOf(actor);

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
      if (CatalogFieldType.DOSE.matches(option.getFieldType())) {
        dosesByVaccine
            .computeIfAbsent(option.getVaccineId(), key -> new ArrayList<>())
            .add(option);
      } else if (CatalogFieldType.PNEUMOCOCCAL_TYPE.matches(option.getFieldType())) {
        pneumoByVaccine
            .computeIfAbsent(option.getVaccineId(), key -> new ArrayList<>())
            .add(option);
      }
    }

    // Opciones operativas institucionales en bloque (1 query).
    Map<UUID, List<InstitutionVaccineOptionEntity>> operationalByVaccine = new LinkedHashMap<>();
    for (InstitutionVaccineOptionEntity option : institutionOptions
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
      result.add(mapper.toEffectiveVaccine(
          vaccine,
          dosesByVaccine.getOrDefault(vaccineId, List.of()),
          pneumoByVaccine.getOrDefault(vaccineId, List.of()),
          operationalByVaccine.getOrDefault(vaccineId, List.of())));
    }
    return new EffectiveCatalogResponse(result);
  }
}
