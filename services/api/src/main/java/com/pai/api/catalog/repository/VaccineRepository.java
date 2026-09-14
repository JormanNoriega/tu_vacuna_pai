package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.VaccineEntity;
import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VaccineRepository extends JpaRepository<VaccineEntity, UUID> {
  Optional<VaccineEntity> findByCode(String code);

  List<VaccineEntity> findByActiveTrueOrderByNameAsc();
}
