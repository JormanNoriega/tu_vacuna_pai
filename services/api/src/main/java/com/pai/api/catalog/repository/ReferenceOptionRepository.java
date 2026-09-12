package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.ReferenceOptionEntity;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReferenceOptionRepository extends JpaRepository<ReferenceOptionEntity, UUID> {

    List<ReferenceOptionEntity> findByCatalogCodeAndActiveTrueOrderBySortOrderAsc(String catalogCode);
}
