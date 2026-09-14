package com.pai.api.shared.security;

import com.pai.api.identity.service.IdentityService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class SecurityBeans {

  @Bean
  public ActiveUserAuthenticationConverter activeUserAuthenticationConverter(
      IdentityService identityService) {
    return new ActiveUserAuthenticationConverter(identityService);
  }
}
