package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.HealthInsurerResponse;
import com.pai.api.catalog.entity.HealthInsurerEntity;
import com.pai.api.catalog.repository.HealthInsurerRepository;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Catalogo global de aseguradoras en salud (EPS). Solo lectura en este hito. */
@Service
public class HealthInsurerService {

  private final HealthInsurerRepository repository;

  public HealthInsurerService(HealthInsurerRepository repository) {
    this.repository = repository;
  }

  /**
   * Lista las aseguradoras activas. Si {@code regime} viene informado, filtra
   * por ese regimen incluyendo siempre las de regimen {@code AMBOS}.
   */
  @Transactional(readOnly = true)
  public List<HealthInsurerResponse> list(String regime) {
    List<HealthInsurerEntity> entities;
    if (regime == null || regime.isBlank()) {
      entities = repository.findByActiveTrueOrderByNameAsc();
    } else {
      String normalized = regime.trim().toUpperCase();
      entities = repository.findByActiveTrueAndRegimeInOrderByNameAsc(Set.of(normalized, "AMBOS"));
    }
    return entities.stream().map(HealthInsurerService::toResponse).toList();
  }

  private static HealthInsurerResponse toResponse(HealthInsurerEntity entity) {
    return new HealthInsurerResponse(
        entity.getId(), entity.getNit(), entity.getName(), entity.getCode(), entity.getRegime());
  }
}
