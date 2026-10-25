package com.pai.api.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.identity.exception.AuthUserProvisioningException;
import com.pai.api.identity.exception.EmailAlreadyExistsException;
import com.pai.api.identity.exception.UncertainProvisioningException;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.HttpServerErrorException;
import org.springframework.web.client.ResourceAccessException;

class SupabaseAuthAdapterTest {

  private SupabaseAuthRestClient adaptee;
  private SupabaseAuthAdapter adapter;

  @BeforeEach
  void setUp() {
    adaptee = mock(SupabaseAuthRestClient.class);
    adapter = new SupabaseAuthAdapter(adaptee);
  }

  @Test
  @DisplayName("Debe adaptar la creacion de usuario y devolver el UUID devuelto por Supabase")
  void createAuthUserSuccess() {
    UUID expectedId = UUID.randomUUID();
    when(adaptee.postCreateAuthUser(eq("jwt-token"), any()))
        .thenReturn(ResponseEntity.ok(Map.of("id", expectedId.toString())));

    UUID operationId = UUID.randomUUID();
    UUID result = adapter.createAuthUser(
        "jwt-token",
        operationId,
        "enfermera@hospital.gov.co",
        "TempPass123!",
        "Laura Gomez",
        null);

    assertThat(result).isEqualTo(expectedId);

    @SuppressWarnings("unchecked")
    ArgumentCaptor<Map<String, Object>> payloadCaptor = ArgumentCaptor.forClass(Map.class);
    verify(adaptee).postCreateAuthUser(eq("jwt-token"), payloadCaptor.capture());

    Map<String, Object> sentPayload = payloadCaptor.getValue();
    assertThat(sentPayload.get("email")).isEqualTo("enfermera@hospital.gov.co");
    assertThat(sentPayload.get("fullName")).isEqualTo("Laura Gomez");
    assertThat(sentPayload.get("operationId")).isEqualTo(operationId);
  }

  @Test
  @DisplayName("Debe traducir HTTP 409 Conflict a EmailAlreadyExistsException")
  void translatesConflictToEmailAlreadyExistsException() {
    when(adaptee.postCreateAuthUser(any(), any()))
        .thenThrow(new HttpClientErrorException(HttpStatus.CONFLICT, "User already exists"));

    assertThatThrownBy(() -> adapter.createAuthUser(
            "jwt-token",
            UUID.randomUUID(),
            "repetido@hospital.gov.co",
            "Pass!",
            "Juan Perez",
            null))
        .isInstanceOf(EmailAlreadyExistsException.class)
        .hasMessageContaining("correo");
  }

  @Test
  @DisplayName("Debe traducir HTTP 500 Server Error a UncertainProvisioningException")
  void translates5xxToUncertainProvisioningException() {
    when(adaptee.postCreateAuthUser(any(), any()))
        .thenThrow(new HttpServerErrorException(HttpStatus.INTERNAL_SERVER_ERROR, "Supabase down"));

    assertThatThrownBy(() -> adapter.createAuthUser(
            "jwt-token",
            UUID.randomUUID(),
            "test@hospital.gov.co",
            "Pass!",
            "Juan Perez",
            null))
        .isInstanceOf(UncertainProvisioningException.class);
  }

  @Test
  @DisplayName("Debe traducir ResourceAccessException a UncertainProvisioningException")
  void translatesNetworkTimeoutToUncertainProvisioningException() {
    when(adaptee.postCreateAuthUser(any(), any()))
        .thenThrow(new ResourceAccessException("Connection timed out"));

    assertThatThrownBy(() -> adapter.createAuthUser(
            "jwt-token",
            UUID.randomUUID(),
            "test@hospital.gov.co",
            "Pass!",
            "Juan Perez",
            null))
        .isInstanceOf(UncertainProvisioningException.class);
  }

  @Test
  @DisplayName("Debe delegar la eliminacion de usuario al cliente REST de Supabase")
  void delegatesDeleteUser() {
    UUID userId = UUID.randomUUID();
    adapter.deleteAuthUser("jwt-token", userId);

    verify(adaptee).deleteAuthUser("jwt-token", userId);
  }
}
