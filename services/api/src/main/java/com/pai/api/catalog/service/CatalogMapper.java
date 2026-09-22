package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.EffectiveCatalogResponse;
import com.pai.api.catalog.dto.InstitutionVaccineResponse;
import com.pai.api.catalog.dto.OptionResponse;
import com.pai.api.catalog.dto.VaccineResponse;
import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineOptionTemplateEntity;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * Concentra el mapeo entidad{@literal ->}DTO del catalogo (SRP). Antes el
 * mapeo de {@code VaccineResponse} y {@code OptionResponse} se repetia en
 * {@code VaccineService}, {@code InstitutionVaccineService} y en las
 * respuestas inline del catalogo efectivo (DRY).
 */
@Component
public class CatalogMapper {

  public VaccineResponse toVaccine(VaccineEntity x) {
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

  public OptionResponse toGlobalOption(VaccineOptionEntity x) {
    return globalOption(
        x.getId(),
        x.getVaccineId(),
        x.getFieldType(),
        x.getValue(),
        x.getDisplayName(),
        x.getSortOrder(),
        x.isDefault(),
        x.isActive(),
        x.getVersion());
  }

  public OptionResponse toTemplate(VaccineOptionTemplateEntity x) {
    return globalOption(
        x.getId(),
        x.getVaccineId(),
        x.getFieldType(),
        x.getValue(),
        x.getDisplayName(),
        x.getSortOrder(),
        x.isDefault(),
        x.isActive(),
        x.getVersion());
  }

  public OptionResponse toInstitutionOption(
      InstitutionVaccineOptionEntity x, UUID vaccineId, UUID institutionId) {
    return new OptionResponse(
        x.getId(),
        vaccineId,
        institutionId,
        x.getFieldType(),
        x.getValue(),
        x.getDisplayName(),
        x.getSortOrder(),
        x.isDefault(),
        x.isActive(),
        x.getSourceTemplateId(),
        x.getVersion());
  }

  public OptionResponse toSuggestedOption(
      VaccineOptionTemplateEntity template, UUID vaccineId, UUID institutionId) {
    return new OptionResponse(
        template.getId(),
        vaccineId,
        institutionId,
        template.getFieldType(),
        template.getValue(),
        template.getDisplayName(),
        template.getSortOrder(),
        false,
        true,
        template.getId(),
        0);
  }

  public InstitutionVaccineResponse toInstitutionVaccine(
      InstitutionVaccineEntity relation, VaccineEntity vaccine, UUID institutionId) {
    return new InstitutionVaccineResponse(
        relation.getId(),
        institutionId,
        vaccine.getId(),
        vaccine.getName(),
        vaccine.getCode(),
        vaccine.getCategory(),
        relation.isEnabled(),
        relation.getVersion());
  }

  /**
   * Ensambla la vacuna del catalogo efectivo con sus dosis, tipos de neumococo
   * y opciones operativas (antes se construia inline en
   * {@code EffectiveCatalogService}).
   */
  public EffectiveCatalogResponse.EffectiveVaccine toEffectiveVaccine(
      VaccineEntity vaccine,
      List<VaccineOptionEntity> doses,
      List<VaccineOptionEntity> pneumococcalTypes,
      List<InstitutionVaccineOptionEntity> operationalOptions) {
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
        globalItems(doses),
        globalItems(pneumococcalTypes),
        institutionItems(operationalOptions));
  }

  private OptionResponse globalOption(
      UUID id,
      UUID vaccineId,
      String fieldType,
      String value,
      String displayName,
      int sortOrder,
      boolean isDefault,
      boolean isActive,
      long version) {
    return new OptionResponse(
        id,
        vaccineId,
        null,
        fieldType,
        value,
        displayName,
        sortOrder,
        isDefault,
        isActive,
        null,
        version);
  }

  private List<EffectiveCatalogResponse.OptionItem> globalItems(List<VaccineOptionEntity> options) {
    List<EffectiveCatalogResponse.OptionItem> items = new ArrayList<>(options.size());
    for (VaccineOptionEntity option : options) {
      items.add(item(
          option.getId(),
          option.getFieldType(),
          option.getValue(),
          option.getDisplayName(),
          option.getSortOrder(),
          option.isDefault()));
    }
    return items;
  }

  private List<EffectiveCatalogResponse.OptionItem> institutionItems(
      List<InstitutionVaccineOptionEntity> options) {
    List<EffectiveCatalogResponse.OptionItem> items = new ArrayList<>(options.size());
    for (InstitutionVaccineOptionEntity option : options) {
      items.add(item(
          option.getId(),
          option.getFieldType(),
          option.getValue(),
          option.getDisplayName(),
          option.getSortOrder(),
          option.isDefault()));
    }
    return items;
  }

  private EffectiveCatalogResponse.OptionItem item(
      UUID id,
      String fieldType,
      String value,
      String displayName,
      int sortOrder,
      boolean isDefault) {
    return new EffectiveCatalogResponse.OptionItem(
        id, fieldType, value, displayName, sortOrder, isDefault);
  }
}
