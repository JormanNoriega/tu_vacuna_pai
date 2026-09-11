package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.GeoCountryEntity;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GeoCountryRepository extends JpaRepository<GeoCountryEntity, UUID> {

    Optional<GeoCountryEntity> findByCode(String code);
}
