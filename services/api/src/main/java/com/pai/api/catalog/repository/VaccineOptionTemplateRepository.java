package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.VaccineOptionTemplateEntity;
import jakarta.persistence.LockModeType;
import java.util.*;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

public interface VaccineOptionTemplateRepository
    extends JpaRepository<VaccineOptionTemplateEntity, UUID>,
        CatalogOptionRepository<VaccineOptionTemplateEntity> {
  List<VaccineOptionTemplateEntity> findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(
      UUID id);

  Optional<VaccineOptionTemplateEntity> findByIdAndVaccineId(UUID id, UUID vaccineId);

  boolean existsByVaccineIdAndFieldTypeAndValueNormalizedAndActiveTrue(
      UUID vaccineId, String fieldType, String valueNormalized);

  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select t from VaccineOptionTemplateEntity t where t.vaccineId=:v and t.active=true")
  List<VaccineOptionTemplateEntity> lockActive(@Param("v") UUID vaccineId);
}
