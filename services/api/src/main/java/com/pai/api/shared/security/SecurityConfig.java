package com.pai.api.shared.security;

import com.pai.api.identity.service.ActiveUserAuthenticationConverter;
import com.pai.api.shared.exceptions.ErrorResponse;
import com.pai.api.shared.json.JsonSerializer;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

  private final JwtDecoder jwtDecoder;
  private final ActiveUserAuthenticationConverter authenticationConverter;
  private final JsonSerializer json;

  public SecurityConfig(
      JwtDecoder jwtDecoder,
      ActiveUserAuthenticationConverter authenticationConverter,
      JsonSerializer json) {
    this.jwtDecoder = jwtDecoder;
    this.authenticationConverter = authenticationConverter;
    this.json = json;
  }

  @Bean
  public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    http.csrf(csrf -> csrf.disable())
        .sessionManagement(
            session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .oauth2ResourceServer(oauth2 -> oauth2
            .jwt(jwt -> jwt.decoder(jwtDecoder).jwtAuthenticationConverter(authenticationConverter))
            .authenticationEntryPoint(new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED)))
        .exceptionHandling(exceptions -> exceptions
            .authenticationEntryPoint((request, response, authException) -> write(
                response,
                HttpStatus.UNAUTHORIZED,
                errorBody(
                    "UNAUTHORIZED",
                    authException.getMessage() == null
                            || authException.getMessage().isBlank()
                        ? "Token de acceso invalido o ausente."
                        : authException.getMessage())))
            .accessDeniedHandler((request, response, accessDeniedException) -> write(
                response,
                HttpStatus.FORBIDDEN,
                errorBody("FORBIDDEN", "No tienes permiso para esta operacion."))))
        .authorizeHttpRequests(auth -> auth.requestMatchers("/actuator/health", "/actuator/info")
            .permitAll()
            .requestMatchers(HttpMethod.OPTIONS, "/**")
            .permitAll()
            .anyRequest()
            .authenticated());

    return http.build();
  }

  private byte[] errorBody(String error, String message) {
    return json.write(new ErrorResponse(error, message)).getBytes(StandardCharsets.UTF_8);
  }

  private static void write(HttpServletResponse response, HttpStatus status, byte[] body)
      throws IOException {
    response.setStatus(status.value());
    response.setContentType(MediaType.APPLICATION_JSON_VALUE);
    response.getOutputStream().write(body);
  }
}
