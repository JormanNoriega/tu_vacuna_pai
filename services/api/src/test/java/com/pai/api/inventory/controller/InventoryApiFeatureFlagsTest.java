package com.pai.api.inventory.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import com.pai.api.inventory.security.InstallationChallengeService;
import com.pai.api.inventory.security.InstallationKeyService;
import com.pai.api.inventory.service.CampaignService;
import com.pai.api.inventory.service.CustodyEventService;
import com.pai.api.inventory.service.InstallationReservationService;
import com.pai.api.inventory.service.InventoryService;
import com.pai.api.shared.security.AuthorizationService;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;

class InventoryApiFeatureFlagsTest {
  @Configuration
  @EnableMethodSecurity
  @Import({InventoryController.class, CampaignController.class, CustodyEventController.class,
      InstallationReservationController.class, InstallationKeyController.class, CustodyWorkflowController.class})
  static class Config {
    @Bean InventoryService inventoryService() { return mock(InventoryService.class); }
    @Bean com.pai.api.inventory.service.InventoryReceiptWorkflow receiptWorkflow() {
      return mock(com.pai.api.inventory.service.InventoryReceiptWorkflow.class);
    }
    @Bean com.pai.api.inventory.service.CustodyWorkflowService workflowService() {
      return mock(com.pai.api.inventory.service.CustodyWorkflowService.class);
    }
    @Bean CampaignService campaignService() { return mock(CampaignService.class); }
    @Bean CustodyEventService custodyEventService() { return mock(CustodyEventService.class); }
    @Bean InstallationReservationService reservationService() { return mock(InstallationReservationService.class); }
    @Bean InstallationKeyService keyService() { return mock(InstallationKeyService.class); }
    @Bean InstallationChallengeService challengeService() { return mock(InstallationChallengeService.class); }
    @Bean(name = "authorization") AuthorizationService authorization() { return new AuthorizationService(); }
  }

  private ApplicationContextRunner runner() {
    return new ApplicationContextRunner()
        .withInitializer(new ConfigDataApplicationContextInitializer())
        .withPropertyValues(
          "app.inventory.api-enabled=false",
          "app.inventory.reservations-enabled=false",
          "app.inventory.installation-keys-enabled=false")
        .withUserConfiguration(Config.class);
  }

  @Test
  void allInventoryHttpApisAreClosedWhenApiDisabled() {
    runner().run(context -> {
      assertThat(context).doesNotHaveBean(InventoryController.class);
      assertThat(context).doesNotHaveBean(CampaignController.class);
      assertThat(context).doesNotHaveBean(CustodyEventController.class);
      assertThat(context).doesNotHaveBean(CustodyWorkflowController.class);
      assertThat(context).doesNotHaveBean(InstallationReservationController.class);
      assertThat(context).doesNotHaveBean(InstallationKeyController.class);
    });
  }

  @Test
  void explicitlyDisabledInstallationApisRemainClosed() {
    runner().withPropertyValues("app.inventory.api-enabled=true",
        "app.inventory.reservations-enabled=false", "app.inventory.installation-keys-enabled=false").run(context -> {
      assertThat(context).hasSingleBean(InventoryController.class);
      assertThat(context).hasSingleBean(CampaignController.class);
      assertThat(context).hasSingleBean(CustodyEventController.class);
      assertThat(context).hasSingleBean(CustodyWorkflowController.class);
      assertThat(context).doesNotHaveBean(InstallationReservationController.class);
      assertThat(context).doesNotHaveBean(InstallationKeyController.class);
    });
  }

  @Test
  void reservationAndKeyApisNeedTheirOwnExplicitFlags() {
    runner().withPropertyValues("app.inventory.api-enabled=true", "app.inventory.reservations-enabled=true",
        "app.inventory.installation-keys-enabled=false")
        .run(context -> {
          assertThat(context).hasSingleBean(InstallationReservationController.class);
          assertThat(context).doesNotHaveBean(InstallationKeyController.class);
        });
    runner().withPropertyValues("app.inventory.api-enabled=true", "app.inventory.reservations-enabled=true",
        "app.inventory.installation-keys-enabled=true").run(context -> {
          assertThat(context).hasSingleBean(InstallationKeyController.class);
        });
  }

  @Test
  void inventoryApisAreEnabledByDefault() {
    new ApplicationContextRunner()
        .withInitializer(new ConfigDataApplicationContextInitializer())
        .withUserConfiguration(Config.class)
        .run(context -> {
          assertThat(context).hasSingleBean(InventoryController.class);
          assertThat(context).hasSingleBean(InstallationReservationController.class);
          assertThat(context).hasSingleBean(InstallationKeyController.class);
        });
  }
}



