package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.HealthInsurerEntity;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HealthInsurerRepository extends JpaRepository<HealthInsurerEntity, UUID> {

  List<HealthInsurerEntity> findByActiveTrueOrderByNameAsc();

  List<HealthInsurerEntity> findByActiveTrueAndRegimeInOrderByNameAsc(Collection<String> regimes);
}
