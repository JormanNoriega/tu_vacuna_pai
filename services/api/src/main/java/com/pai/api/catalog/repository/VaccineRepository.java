package com.pai.api.catalog.repository;
import java.util.*; import org.springframework.data.jpa.repository.JpaRepository; import com.pai.api.catalog.entity.VaccineEntity;
public interface VaccineRepository extends JpaRepository<VaccineEntity, UUID> { Optional<VaccineEntity> findByCode(String code); List<VaccineEntity> findByActiveTrueOrderByNameAsc(); }
