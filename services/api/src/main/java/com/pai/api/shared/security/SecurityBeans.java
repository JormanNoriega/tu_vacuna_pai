package com.pai.api.shared.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.pai.api.identity.service.IdentityService;

@Configuration
public class SecurityBeans {

    @Bean
    public ActiveUserAuthenticationConverter activeUserAuthenticationConverter(
            IdentityService identityService) {
        return new ActiveUserAuthenticationConverter(identityService);
    }
}