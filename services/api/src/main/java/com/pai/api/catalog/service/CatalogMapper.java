package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.InstitutionVaccineResponse;
import com.pai.api.catalog.dto.OptionResponse;
import com.pai.api.catalog.dto.VaccineResponse;
import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineOptionTemplateEntity;
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

  public OptionResponse toTemplate(VaccineOptionTemplateEntity x) {
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
}
