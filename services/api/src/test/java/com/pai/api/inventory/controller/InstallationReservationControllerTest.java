package com.pai.api.inventory.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.inventory.service.InstallationReservationService;
import com.pai.api.shared.security.AuthorizationService;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.core.context.SecurityContextHolder;

class InstallationReservationControllerTest {
  @Configuration
  @EnableMethodSecurity
  @Import(InstallationReservationController.class)
  static class Config {
    @Bean InstallationReservationService service() { return mock(InstallationReservationService.class); }
    @Bean(name = "authorization") AuthorizationService authorization() { return new AuthorizationService(); }
  }

  @AfterEach void clear() { SecurityContextHolder.clearContext(); }

  @Test
  void bothFlagsAreRequired() {
    var runner = new ApplicationContextRunner().withUserConfiguration(Config.class);
    runner.withPropertyValues("app.inventory.api-enabled=true").run(context ->
        assertThat(context).doesNotHaveBean(InstallationReservationController.class));
    runner.withPropertyValues("app.inventory.reservations-enabled=true").run(context ->
        assertThat(context).doesNotHaveBean(InstallationReservationController.class));
    runner.withPropertyValues("app.inventory.api-enabled=true", "app.inventory.reservations-enabled=true").run(context ->
        assertThat(context).hasSingleBean(InstallationReservationController.class));
  }

  @Test
  void reservationRequiresWriteAndRegistrationRequiresClinicalPermission() {
    new ApplicationContextRunner().withUserConfiguration(Config.class)
        .withPropertyValues("app.inventory.api-enabled=true", "app.inventory.reservations-enabled=true")
        .run(context -> {
          var controller = context.getBean(InstallationReservationController.class);
          var service = context.getBean(InstallationReservationService.class);
          var user = mock(AuthorizedUser.class);
          var auth = UsernamePasswordAuthenticationToken.authenticated(user, "", List.of());
          SecurityContextHolder.getContext().setAuthentication(auth);
          UUID id = UUID.randomUUID();
          when(user.hasPermission("INVENTORY_READ")).thenReturn(true);
          assertThatThrownBy(() -> controller.reserve(auth, id,
              new InstallationReservationController.ReserveRequest(id, id, id, 1)))
              .isInstanceOf(AccessDeniedException.class);
          assertThatThrownBy(() -> controller.register(auth, id,
              new InstallationReservationController.RegisterRequest(id, "equipo")))
              .isInstanceOf(AccessDeniedException.class);
          verifyNoInteractions(service);
        });
  }

  @Test
  void installationAndReservationListsRequireInventoryRead() {
    new ApplicationContextRunner().withUserConfiguration(Config.class)
        .withPropertyValues("app.inventory.api-enabled=true", "app.inventory.reservations-enabled=true")
        .run(context -> {
          var controller = context.getBean(InstallationReservationController.class);
          var service = context.getBean(InstallationReservationService.class);
          var user = mock(AuthorizedUser.class);
          var auth = UsernamePasswordAuthenticationToken.authenticated(user, "", List.of());
          SecurityContextHolder.getContext().setAuthentication(auth);
          UUID institution = UUID.randomUUID();
          assertThatThrownBy(() -> controller.list(auth, institution)).isInstanceOf(AccessDeniedException.class);
          assertThatThrownBy(() -> controller.reservations(auth, institution)).isInstanceOf(AccessDeniedException.class);
          verifyNoInteractions(service);
        });
  }
}
