package com.pai.api.geography;

import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@ConditionalOnProperty(name = "app.geography.enabled", havingValue = "true")
class GeographyAggregation {
  private static final ZoneId ZONE = ZoneId.of("America/Bogota");
  private final EntityManager entityManager;
  private final double cellSize;
  private final int minimum;

  GeographyAggregation(EntityManager entityManager,
      @Value("${app.geography.cell-size-degrees:0.018}") double cellSize,
      @Value("${app.geography.minimum-attentions:5}") int minimum) {
    if (!Double.isFinite(cellSize) || cellSize <= 0 || cellSize > 10 || minimum < 2) {
      throw new IllegalArgumentException("Configuración geográfica inválida");
    }
    this.entityManager = entityManager;
    this.cellSize = cellSize;
    this.minimum = minimum;
  }

  @Cacheable(cacheNames = "geographyAttentions", cacheManager = "geographyCacheManager", sync = true)
  @Transactional(readOnly = true)
  public GeographyResponse load(UUID institutionId, int days, LocalDate today) {
    Instant from = today.minusDays(days - 1L).atStartOfDay(ZONE).toInstant();
    Instant until = today.plusDays(1).atStartOfDay(ZONE).toInstant();
    @SuppressWarnings("unchecked")
    List<Object[]> rows = entityManager.createNativeQuery("""
        SELECT greatest(-90.0, least(90.0, (grid_lat + 0.5) * :size)) AS lat,
               greatest(-180.0, least(180.0, (grid_lon + 0.5) * :size)) AS lon,
               count(*) AS total
        FROM (
          SELECT floor(latitude / :size) AS grid_lat,
                 floor(longitude / :size) AS grid_lon
          FROM app.attentions
          WHERE institution_id = :institution AND status = 'COMPLETED'
            AND attention_date >= :fromDate AND attention_date < :untilDate
            AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180
        ) AS gridded
        GROUP BY grid_lat, grid_lon
        HAVING count(*) >= :minimum
        """)
        .setParameter("size", cellSize)
        .setParameter("institution", institutionId)
        .setParameter("fromDate", from)
        .setParameter("untilDate", until)
        .setParameter("minimum", minimum)
        .getResultList();
    List<GeographyResponse.Cell> cells = rows.stream().map(row ->
        new GeographyResponse.Cell(((Number) row[0]).doubleValue(),
            ((Number) row[1]).doubleValue(), ((Number) row[2]).longValue())).toList();
    return new GeographyResponse(days, today, Instant.now(), cells);
  }
}
