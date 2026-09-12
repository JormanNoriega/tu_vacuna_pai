package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import java.util.*;
import org.springframework.data.jpa.repository.*;

public interface InstitutionVaccineRepository extends JpaRepository<InstitutionVaccineEntity, UUID> {
    Optional<InstitutionVaccineEntity> findByInstitutionIdAndVaccineId(UUID i, UUID v);

    List<InstitutionVaccineEntity> findByInstitutionId(UUID i);
}
