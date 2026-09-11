package com.pai.api.catalog.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.pai.api.catalog.entity.GeoCountryEntity;

public interface GeoCountryRepository extends JpaRepository<GeoCountryEntity, UUID> {

    Optional<GeoCountryEntity> findByCode(String code);
}
