package com.pai.api.inventory.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.inventory.security.InstallationKeyService;
import com.pai.api.shared.security.AuthorizationService;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class InstallationKeyControllerTest {
  @Configuration @EnableMethodSecurity @Import(InstallationKeyController.class)
  static class Config {
    @Bean InstallationKeyService service() { return mock(InstallationKeyService.class); }
    @Bean(name = "authorization") AuthorizationService authorization() { return new AuthorizationService(); }
  }
  private final ApplicationContextRunner runner = new ApplicationContextRunner().withUserConfiguration(Config.class);
  private static final String[] ENABLED = {"app.inventory.api-enabled=true", "app.inventory.reservations-enabled=true", "app.inventory.installation-keys-enabled=true"};
  @AfterEach void clear() { SecurityContextHolder.clearContext(); }

  @Test void everyFlagIsRequired() {
    runner.run(c -> assertThat(c).doesNotHaveBean(InstallationKeyController.class));
    runner.withPropertyValues(ENABLED[0], ENABLED[1]).run(c -> assertThat(c).doesNotHaveBean(InstallationKeyController.class));
    runner.withPropertyValues(ENABLED[0], ENABLED[2]).run(c -> assertThat(c).doesNotHaveBean(InstallationKeyController.class));
    runner.withPropertyValues(ENABLED[1], ENABLED[2]).run(c -> assertThat(c).doesNotHaveBean(InstallationKeyController.class));
    runner.withPropertyValues(ENABLED).run(c -> assertThat(c).hasSingleBean(InstallationKeyController.class));
  }

  @Test void permissionsAreIndependentAndAuthenticatedActorIsUsed() {
    runner.withPropertyValues(ENABLED).run(c -> {
      var controller = c.getBean(InstallationKeyController.class);
      var service = c.getBean(InstallationKeyService.class);
      UUID actor = UUID.randomUUID(), institution = UUID.randomUUID(), installation = UUID.randomUUID();
      var user = mock(AuthorizedUser.class);
      when(user.getId()).thenReturn(actor);
      when(user.hasPermission("ATTENTION_CREATE")).thenReturn(true);
      var auth = UsernamePasswordAuthenticationToken.authenticated(user, "", List.of());
      SecurityContextHolder.getContext().setAuthentication(auth);
      assertThatThrownBy(() -> controller.revoke(auth, institution, installation,
          new InstallationKeyController.RevokeRequest("motivo"))).isInstanceOf(AccessDeniedException.class);
      controller.begin(auth, institution, installation, new InstallationKeyController.BeginRequest(new byte[] {1}));
      verify(service).begin(eq(actor), eq(institution), eq(installation), any());
      when(user.hasPermission("ATTENTION_CREATE")).thenReturn(false);
      when(user.hasPermission("INVENTORY_WRITE")).thenReturn(true);
      assertThatThrownBy(() -> controller.complete(auth, institution, installation,
          new InstallationKeyController.CompleteRequest(UUID.randomUUID(), new byte[] {1}, new byte[64])))
          .isInstanceOf(AccessDeniedException.class);
      controller.revoke(auth, institution, installation, new InstallationKeyController.RevokeRequest("motivo"));
      verify(service).revoke(actor, institution, installation, "motivo");
    });
  }

  @Test void httpRejectsMalformedInputsBeforeCallingService() {
    runner.withPropertyValues(ENABLED).run(c -> {
      var controller = c.getBean(InstallationKeyController.class);
      var service = c.getBean(InstallationKeyService.class);
      var user = mock(AuthorizedUser.class);
      when(user.hasPermission("ATTENTION_CREATE")).thenReturn(true);
      when(user.hasPermission("INVENTORY_WRITE")).thenReturn(true);
      var auth = UsernamePasswordAuthenticationToken.authenticated(user, "", List.of());
      SecurityContextHolder.getContext().setAuthentication(auth);
      var mvc = MockMvcBuilders.standaloneSetup(controller).build();
      String base = "/api/v1/institutions/" + UUID.randomUUID() + "/inventory/installations/" + UUID.randomUUID() + "/key";
      mvc.perform(post(base + "/confirm").principal(auth).contentType(MediaType.APPLICATION_JSON)
          .content("{\"challengeId\":\"" + UUID.randomUUID() + "\",\"publicKey\":\"AQ==\",\"signature\":\"AQ==\"}"))
          .andExpect(status().isBadRequest());
      mvc.perform(post(base + "/revoke").principal(auth).contentType(MediaType.APPLICATION_JSON)
          .content("{\"note\":\" \"}")).andExpect(status().isBadRequest());
      verifyNoInteractions(service);
    });
  }
}
