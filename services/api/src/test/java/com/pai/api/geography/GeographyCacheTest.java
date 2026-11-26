package com.pai.api.geography;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.aop.support.AopUtils;
import org.springframework.boot.convert.ApplicationConversionService;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.core.env.MapPropertySource;
import java.util.Map;

class GeographyCacheTest {
  @Test
  void proxyCoalescesConcurrentRequestsAndSeparatesInstitutionsAndPeriods() throws Exception {
    EntityManager entityManager = mock(EntityManager.class);
    Query query = mock(Query.class, org.mockito.Mockito.RETURNS_SELF);
    CountDownLatch queryStarted = new CountDownLatch(1);
    CountDownLatch releaseQuery = new CountDownLatch(1);
    when(entityManager.createNativeQuery(anyString())).thenReturn(query);
    when(query.getResultList()).thenAnswer(invocation -> {
      queryStarted.countDown();
      if (!releaseQuery.await(5, TimeUnit.SECONDS)) {
        throw new IllegalStateException("La prueba agotó el tiempo de espera");
      }
      return List.of();
    });

    try (var context = new AnnotationConfigApplicationContext()) {
      context.getBeanFactory().setConversionService(ApplicationConversionService.getSharedInstance());
      context.getEnvironment().getPropertySources().addFirst(
          new MapPropertySource("test", Map.of("app.geography.enabled", "true")));
      context.registerBean(EntityManager.class, () -> entityManager);
      context.register(GeographyConfiguration.class, GeographyAggregation.class);
      context.refresh();
      GeographyAggregation aggregation = context.getBean(GeographyAggregation.class);
      assertThat(AopUtils.isAopProxy(aggregation)).isTrue();
      UUID institution = UUID.randomUUID();
      LocalDate day = LocalDate.of(2026, 11, 25);

      try (var executor = Executors.newFixedThreadPool(2)) {
        var first = executor.submit(() -> aggregation.load(institution, 30, day));
        assertThat(queryStarted.await(5, TimeUnit.SECONDS)).isTrue();
        var second = executor.submit(() -> aggregation.load(institution, 30, day));
        releaseQuery.countDown();
        assertThat(second.get(5, TimeUnit.SECONDS)).isSameAs(first.get(5, TimeUnit.SECONDS));
      }
      aggregation.load(UUID.randomUUID(), 30, day);
      aggregation.load(institution, 7, day);
      aggregation.load(institution, 30, day.plusDays(1));
      verify(entityManager, times(4)).createNativeQuery(anyString());
    }
  }
}
