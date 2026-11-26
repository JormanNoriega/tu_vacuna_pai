package com.pai.api.geography;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

class GeographyAggregationTest {
  @Test
  void calculatesInclusiveBogotaDaysWithExclusiveNextMidnight() {
    EntityManager entityManager = mock(EntityManager.class);
    Query query = mock(Query.class, Mockito.RETURNS_SELF);
    when(entityManager.createNativeQuery(anyString())).thenReturn(query);
    when(query.getResultList()).thenReturn(List.of());
    UUID institution = UUID.randomUUID();
    GeographyAggregation aggregation = new GeographyAggregation(entityManager, .018, 5);

    GeographyResponse result = aggregation.load(institution, 7, LocalDate.of(2026, 11, 25));

    verify(query).setParameter("institution", institution);
    verify(query).setParameter("fromDate", Instant.parse("2026-11-19T05:00:00Z"));
    verify(query).setParameter("untilDate", Instant.parse("2026-11-26T05:00:00Z"));
    verify(query).setParameter("minimum", 5);
    assertThat(result.cells()).isEmpty();
  }
}
