package com.pai.api.inventory.service;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import javax.sql.DataSource;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.transaction.support.TransactionTemplate;

class InventoryEventStreamTest {
  @Configuration
  @EnableTransactionManagement
  static class Config {
    @Bean IdentityService identity() { return mock(IdentityService.class); }
    @Bean DataScope scope() { return new DataScope(); }
    @Bean InventoryEventStream stream(IdentityService identity, DataScope scope) {
      return new InventoryEventStream(identity, scope);
    }
    @Bean DataSource dataSource() {
      return new DriverManagerDataSource("jdbc:h2:mem:inventory_events;DB_CLOSE_DELAY=-1", "sa", "");
    }
    @Bean PlatformTransactionManager transactionManager(DataSource source) {
      return new DataSourceTransactionManager(source);
    }
  }

  @Test
  void onlyDispatchesAfterCommitAndIgnoresOtherInstitutions() {
    try (var context = new AnnotationConfigApplicationContext(Config.class)) {
      var identity = context.getBean(IdentityService.class);
      var stream = context.getBean(InventoryEventStream.class);
      var institution = UUID.randomUUID();
      var vaccinator = UUID.randomUUID();
      var profile = mock(AuthorizedUser.class);
      var institutionProfile = mock(InstitutionEntity.class);
      when(institutionProfile.getId()).thenReturn(institution);
      when(profile.getInstitution()).thenReturn(institutionProfile);
      when(profile.getPermissions()).thenReturn(List.of("ATTENTION_CREATE"));
      when(profile.hasPermission("ATTENTION_CREATE")).thenReturn(true);
      when(identity.resolve(vaccinator)).thenReturn(profile);
      var emitter = stream.subscribe(vaccinator, institution, Instant.now().plusSeconds(60));
      var event = new InventoryChange("DELIVERY_CREATED", institution, UUID.randomUUID(),
          UUID.randomUUID(), vaccinator);
      var tx = new TransactionTemplate(context.getBean(PlatformTransactionManager.class));
      reset(identity);
      when(identity.resolve(vaccinator)).thenReturn(profile);
      tx.executeWithoutResult(status -> {
        context.publishEvent(event);
        verifyNoInteractions(identity);
        status.setRollbackOnly();
      });
      verifyNoInteractions(identity);
      tx.executeWithoutResult(status -> context.publishEvent(event));
      verify(identity, times(1)).resolve(vaccinator);
      tx.executeWithoutResult(status -> context.publishEvent(new InventoryChange(
          "DELIVERY_CREATED", UUID.randomUUID(), event.assignmentId(), event.eventId(), vaccinator)));
      verify(identity, times(1)).resolve(vaccinator);
      emitter.complete();
    }
  }

  @Test
  void rejectsSubscriptionForAnotherInstitution() {
    var identity = mock(IdentityService.class);
    var user = mock(AuthorizedUser.class);
    var institution = mock(InstitutionEntity.class);
    when(institution.getId()).thenReturn(UUID.randomUUID());
    when(user.getInstitution()).thenReturn(institution);
    when(user.getPermissions()).thenReturn(List.of("ATTENTION_CREATE"));
    var actor = UUID.randomUUID();
    when(identity.resolve(actor)).thenReturn(user);
    var stream = new InventoryEventStream(identity, new DataScope());
    assertThatThrownBy(() -> stream.subscribe(actor, UUID.randomUUID(), Instant.now().plusSeconds(60)))
        .isInstanceOf(com.pai.api.shared.exceptions.ScopeViolationException.class);
  }
}
