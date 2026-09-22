package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.GeoMunicipalityEntity;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GeoMunicipalityRepository extends JpaRepository<GeoMunicipalityEntity, UUID> {

  List<GeoMunicipalityEntity> findByDepartmentIdOrderByNameAsc(UUID departmentId);

  /** Todos los municipios ordenados por nombre (precarga del catalogo completo). */
  List<GeoMunicipalityEntity> findAllByOrderByNameAsc();
}
