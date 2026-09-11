package com.pai.api.catalog.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.pai.api.catalog.entity.GeoMunicipalityEntity;

public interface GeoMunicipalityRepository
        extends JpaRepository<GeoMunicipalityEntity, UUID> {

    Optional<GeoMunicipalityEntity> findByCode(String code);

    List<GeoMunicipalityEntity> findByDepartmentIdOrderByNameAsc(UUID departmentId);
}
