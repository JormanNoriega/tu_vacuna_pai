package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.VaccineOptionEntity;
import java.util.*;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

public interface VaccineOptionRepository
    extends JpaRepository<VaccineOptionEntity, UUID>, CatalogOptionRepository<VaccineOptionEntity> {
  List<VaccineOptionEntity> findByVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(UUID id);

  List<VaccineOptionEntity>
      findByVaccineIdInAndActiveTrueOrderByVaccineIdAscSortOrderAscDisplayNameAsc(
          Collection<UUID> vaccineIds);

  Optional<VaccineOptionEntity> findByIdAndVaccineId(UUID id, UUID vaccineId);

  boolean existsByVaccineIdAndFieldTypeAndValueNormalizedAndActiveTrue(
      UUID vaccineId, String fieldType, String valueNormalized);

  @Query("select o from VaccineOptionEntity o where o.vaccineId=:v and o.active=true order by"
      + " o.sortOrder,o.displayName")
  List<VaccineOptionEntity> lockActive(@Param("v") UUID vaccineId);
}
