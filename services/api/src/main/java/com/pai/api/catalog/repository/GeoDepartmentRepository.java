package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.GeoDepartmentEntity;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GeoDepartmentRepository extends JpaRepository<GeoDepartmentEntity, UUID> {

  Optional<GeoDepartmentEntity> findByCode(String code);

  List<GeoDepartmentEntity> findAllByOrderByNameAsc();
}
