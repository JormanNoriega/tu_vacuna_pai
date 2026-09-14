package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.ReferenceCatalogEntity;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReferenceCatalogRepository extends JpaRepository<ReferenceCatalogEntity, String> {

  List<ReferenceCatalogEntity> findAllByOrderByCodeAsc();
}
