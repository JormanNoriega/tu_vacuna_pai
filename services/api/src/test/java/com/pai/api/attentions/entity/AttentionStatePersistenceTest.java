package com.pai.api.attentions.entity;

import static org.assertj.core.api.Assertions.assertThat;

import com.pai.api.attentions.state.CancelledState;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.cfg.Configuration;
import org.junit.jupiter.api.Test;

class AttentionStatePersistenceTest {
  @Test
  void persistsReloadsAndFiltersConvertedState() {
    var configuration = new Configuration()
        .addAnnotatedClass(AttentionEntity.class)
        .addAttributeConverter(AttentionStateConverter.class)
        .setProperty("hibernate.connection.driver_class", "org.h2.Driver")
        .setProperty("hibernate.connection.url",
            "jdbc:h2:mem:attention_state;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;INIT=CREATE SCHEMA IF NOT EXISTS app")
        .setProperty("hibernate.hbm2ddl.auto", "create-drop");
    try (var factory = configuration.buildSessionFactory()) {
      UUID institution = UUID.randomUUID();
      UUID professional = UUID.randomUUID();
      UUID activeId = UUID.randomUUID();
      UUID cancelledId = UUID.randomUUID();
      Instant now = Instant.now();
      try (var session = factory.openSession()) {
        var tx = session.beginTransaction();
        var active = new AttentionEntity(activeId, UUID.randomUUID(), professional, institution,
            now, 1L, null, now);
        var cancelled = new AttentionEntity(cancelledId, UUID.randomUUID(), professional,
            institution, now, 2L, null, now);
        cancelled.cancel(now);
        session.persist(active);
        session.persist(cancelled);
        tx.commit();
      }
      try (var session = factory.openSession()) {
        var tx = session.beginTransaction();
        assertThat(session.find(AttentionEntity.class, cancelledId).getStatus().code())
            .isEqualTo("CANCELLED");
        assertThat(session.createQuery(
                "select count(distinct a.patientId) from AttentionEntity a "
                    + "where a.institutionId = :institution and a.status <> :excluded", Long.class)
            .setParameter("institution", institution)
            .setParameter("excluded", CancelledState.INSTANCE)
            .getSingleResult()).isEqualTo(1L);
        assertThat(session.createQuery(
                "select a from AttentionEntity a where a.institutionId = :institution "
                    + "and a.professionalId = :professional and a.status <> :excluded "
                    + "order by a.attentionDate desc, a.createdAt desc", AttentionEntity.class)
            .setParameter("institution", institution)
            .setParameter("professional", professional)
            .setParameter("excluded", CancelledState.INSTANCE)
            .getResultList()).extracting(AttentionEntity::getId).containsExactly(activeId);
        assertThat(session.createNativeQuery(
                "select status from app.attentions where id = :id", String.class)
            .setParameter("id", cancelledId).getSingleResult()).isEqualTo("CANCELLED");
        tx.commit();
      }
    }
  }
}
