package com.pai.api.catalog.service;

import static org.junit.jupiter.api.Assertions.*;

import com.pai.api.attentions.dto.AppliedDoseItem;
import com.pai.api.attentions.dto.DoseExtrinsicContext;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.exception.InconsistentFlyweightException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

@DisplayName("Patrón Estructural: Flyweight (VaccineFlyweight & VaccineFlyweightFactory)")
class VaccineFlyweightTest {

  private VaccineFlyweightFactory factory;

  @BeforeEach
  void setUp() {
    factory = new VaccineFlyweightFactory();
  }

  @Test
  @DisplayName("La fábrica debe reutilizar la misma instancia en memoria para 1.000 dosis de la misma vacuna")
  void returnsSameInstanceForRepeatedCalls() {
    VaccineFlyweight original = factory.getFlyweight(
        "PENTA", "Pentavalente (DTP-HB-Hib)", "BIOLOGICO_INFANTIL", true, true);

    for (int i = 0; i < 1000; i++) {
      VaccineFlyweight current = factory.getFlyweight(
          "PENTA", "Pentavalente (DTP-HB-Hib)", "BIOLOGICO_INFANTIL", true, true);
      assertSame(original, current, "Debe ser exactamente la misma referencia de memoria en el Heap");
    }

    assertEquals(1, factory.getPoolSize(), "El pool debe contener únicamente 1 objeto compartido");
  }

  @Test
  @DisplayName("Integración directa con VaccineEntity: obtiene y reutiliza la instancia a partir de la entidad JPA")
  void integratesDirectlyWithVaccineEntity() {
    VaccineEntity entity = new VaccineEntity(
        UUID.randomUUID(),
        "Tuberculosis BCG",
        "BCG",
        "BIOLOGICO_BACTERIANO",
        (short) 1,
        0,
        1,
        UUID.randomUUID(),
        Instant.now());

    VaccineFlyweight fromEntity = factory.getFlyweight(entity);
    VaccineFlyweight fromCode = factory.getFlyweight(
        "BCG", "Tuberculosis BCG", "BIOLOGICO_BACTERIANO", false, false);

    assertSame(fromEntity, fromCode, "Debe compartir la misma instancia entre la entidad y la consulta directa");
    assertEquals(1, factory.getPoolSize());
  }

  @Test
  @DisplayName("El pool administra múltiples vacunas distintas manteniendo una sola instancia por cada código")
  void supportsMultipleDistinctVaccinesInPool() {
    VaccineFlyweight bcg1 = factory.getFlyweight("BCG", "Tuberculosis BCG", "BIOLOGICO_BACTERIANO", true, true);
    VaccineFlyweight bcg2 = factory.getFlyweight("BCG", "Tuberculosis BCG", "BIOLOGICO_BACTERIANO", true, true);

    VaccineFlyweight polio1 = factory.getFlyweight("POLIO_ORAL", "Polio Oral (BOPV)", "BIOLOGICO_VIRAL", true, false);
    VaccineFlyweight polio2 = factory.getFlyweight("POLIO_ORAL", "Polio Oral (BOPV)", "BIOLOGICO_VIRAL", true, false);

    VaccineFlyweight influenza = factory.getFlyweight("INFLUENZA", "Influenza Estacional", "BIOLOGICO_VIRAL", true, true);

    assertSame(bcg1, bcg2);
    assertSame(polio1, polio2);
    assertNotSame(bcg1, polio1);
    assertNotSame(bcg1, influenza);

    assertEquals(3, factory.getPoolSize(), "Debe haber exactamente 3 instancias en el pool");
    assertSame(bcg1, factory.getExisting("bcg"), "La búsqueda insensible a mayúsculas debe retornar la instancia");
  }

  @Test
  @DisplayName("Lanza InconsistentFlyweightException si se solicita el mismo código con atributos contradictorios")
  void throwsExceptionOnInconsistentIntrinsicAttributes() {
    factory.getFlyweight("FIEBRE_AMARILLA", "Fiebre Amarilla", "BIOLOGICO_VIRAL", true, true);

    // Mismo código pero diferente requerimiento de jeringa
    InconsistentFlyweightException ex1 = assertThrows(
        InconsistentFlyweightException.class,
        () -> factory.getFlyweight("FIEBRE_AMARILLA", "Fiebre Amarilla", "BIOLOGICO_VIRAL", true, false));
    assertTrue(ex1.getMessage().contains("requiresSyringe"));

    // Mismo código pero diferente nombre
    InconsistentFlyweightException ex2 = assertThrows(
        InconsistentFlyweightException.class,
        () -> factory.getFlyweight("FIEBRE_AMARILLA", "Nombre Alterado", "BIOLOGICO_VIRAL", true, true));
    assertTrue(ex2.getMessage().contains("nombre"));
  }

  @Test
  @DisplayName("Combina el estado intrínseco compartido con el estado extrínseco particular sin mutar la vacuna")
  void formatsSummaryWithExtrinsicStateWithoutMutatingFlyweight() {
    VaccineFlyweight penta = factory.getFlyweight(
        "PENTA", "Pentavalente", "BIOLOGICO_INFANTIL", true, true);

    Instant now = Instant.now();
    DoseExtrinsicContext doseJuan = new DoseExtrinsicContext(
        UUID.randomUUID(), UUID.randomUUID(), "1020304050", "LOTE-A01", now, "Primera Dosis", "Enf. Gómez");

    DoseExtrinsicContext doseMaria = new DoseExtrinsicContext(
        UUID.randomUUID(), UUID.randomUUID(), "9876543210", "LOTE-B99", now, "Primera Dosis", "Enf. Gómez");

    AppliedDoseItem itemJuan = new AppliedDoseItem(doseJuan, penta);
    AppliedDoseItem itemMaria = new AppliedDoseItem(doseMaria, penta);

    assertSame(itemJuan.getVaccine(), itemMaria.getVaccine(), "Ambos ítems comparten el mismo Flyweight");

    String summaryJuan = itemJuan.getSummary();
    String summaryMaria = itemMaria.getSummary();

    assertTrue(summaryJuan.contains("1020304050"));
    assertTrue(summaryJuan.contains("LOTE-A01"));
    assertTrue(summaryJuan.contains("Pentavalente"));

    assertTrue(summaryMaria.contains("9876543210"));
    assertTrue(summaryMaria.contains("LOTE-B99"));
    assertTrue(summaryMaria.contains("Pentavalente"));

    assertNotEquals(summaryJuan, summaryMaria, "Los resúmenes deben diferir por el estado extrínseco");
  }

  @Test
  @DisplayName("Acceso concurrente thread-safe garantizado en entornos multihilo")
  void threadSafeConcurrentAccess() throws Exception {
    int threads = 16;
    int iterationsPerThread = 50;
    ExecutorService executor = Executors.newFixedThreadPool(threads);
    CountDownLatch startGate = new CountDownLatch(1);
    CountDownLatch endGate = new CountDownLatch(threads);
    List<VaccineFlyweight> results = Collections.synchronizedList(new ArrayList<>());

    for (int t = 0; t < threads; t++) {
      executor.submit(() -> {
        try {
          startGate.await();
          for (int i = 0; i < iterationsPerThread; i++) {
            VaccineFlyweight instance = factory.getFlyweight(
                "HEPATITIS_B", "Hepatitis B Pediátrica", "BIOLOGICO_VIRAL", true, true);
            results.add(instance);
          }
        } catch (Exception e) {
          throw new RuntimeException(e);
        } finally {
          endGate.countDown();
        }
      });
    }

    startGate.countDown();
    endGate.await();
    executor.shutdown();

    assertEquals(threads * iterationsPerThread, results.size());
    VaccineFlyweight reference = results.get(0);
    for (VaccineFlyweight v : results) {
      assertSame(reference, v, "Cada llamada concurrente debió retornar la misma instancia compartida");
    }
    assertEquals(1, factory.getPoolSize(), "A pesar de la alta concurrencia, solo debe crearse 1 instancia");
  }
}
