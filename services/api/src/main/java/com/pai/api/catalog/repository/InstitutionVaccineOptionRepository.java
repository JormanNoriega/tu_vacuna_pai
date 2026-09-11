package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import java.util.*;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

public interface InstitutionVaccineOptionRepository extends JpaRepository<InstitutionVaccineOptionEntity, UUID> {
    List<InstitutionVaccineOptionEntity> findByInstitutionIdAndVaccineIdAndActiveTrueOrderBySortOrderAscDisplayNameAsc(
            UUID i, UUID v);

    List<InstitutionVaccineOptionEntity>
            findByInstitutionIdAndVaccineIdInAndActiveTrueOrderByVaccineIdAscSortOrderAscDisplayNameAsc(
                    UUID i, Collection<UUID> vaccineIds);

    Optional<InstitutionVaccineOptionEntity> findByIdAndInstitutionIdAndVaccineId(UUID id, UUID i, UUID v);

    @Query("select o from InstitutionVaccineOptionEntity o where o.institutionId=:i and o.vaccineId=:v and"
            + " o.active=true order by o.sortOrder,o.displayName")
    List<InstitutionVaccineOptionEntity> lockActive(@Param("i") UUID i, @Param("v") UUID v);
}
