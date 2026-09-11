package com.pai.api.catalog.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.pai.api.catalog.entity.GeoDepartmentEntity;

public interface GeoDepartmentRepository extends JpaRepository<GeoDepartmentEntity, UUID> {

    Optional<GeoDepartmentEntity> findByCode(String code);

    List<GeoDepartmentEntity> findAllByOrderByNameAsc();
}
