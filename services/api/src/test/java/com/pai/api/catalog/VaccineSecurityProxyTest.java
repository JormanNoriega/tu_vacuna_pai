package com.pai.api.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.catalog.dto.VaccineRequest;
import com.pai.api.catalog.dto.VaccineResponse;
import com.pai.api.catalog.service.VaccineSecurityProxy;
import com.pai.api.catalog.service.VaccineService;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.shared.exceptions.PermissionDeniedException;
import com.pai.api.shared.security.PermissionGuard;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class VaccineSecurityProxyTest {

  private static final UUID ACTOR_ID = UUID.randomUUID();
  private static final UUID VACCINE_ID = UUID.randomUUID();

  private VaccineService realService;
  private PermissionGuard guard;
  private VaccineSecurityProxy proxy;

  @BeforeEach
  void setUp() {
    realService = mock(VaccineService.class);
    guard = mock(PermissionGuard.class);
    proxy = new VaccineSecurityProxy(realService, guard);
  }

  private AuthorizedUser actor() {
    return new AuthorizedUser(
        ACTOR_ID,
        "admin@test.com",
        "Admin",
        new InstitutionEntity(
            UUID.randomUUID(),
            "HOSP-1",
            "Hospital 1",
            InstitutionEntity.Status.ACTIVE,
            (short) 72,
            Instant.now(),
            Instant.now()),
        List.of("ADMIN"),
        List.of("CATALOG_GLOBAL_READ", "CATALOG_GLOBAL_WRITE"),
        Instant.now());
  }

  @Test
  @DisplayName("list() delega en el sujeto real cuando el permiso CATALOG_GLOBAL_READ es valido")
  void list_whenAuthorized_delegatesToRealService() {
    when(guard.require(ACTOR_ID, "CATALOG_GLOBAL_READ")).thenReturn(actor());
    List<VaccineResponse> expected = List.of();
    when(realService.list(ACTOR_ID)).thenReturn(expected);

    List<VaccineResponse> result = proxy.list(ACTOR_ID);

    assertThat(result).isSameAs(expected);
    verify(guard).require(ACTOR_ID, "CATALOG_GLOBAL_READ");
    verify(realService).list(ACTOR_ID);
  }

  @Test
  @DisplayName("list() lanza PermissionDeniedException y NO invoca al sujeto real si falta permiso")
  void list_whenUnauthorized_blocksExecution() {
    when(guard.require(ACTOR_ID, "CATALOG_GLOBAL_READ"))
        .thenThrow(new PermissionDeniedException("Permiso insuficiente: CATALOG_GLOBAL_READ"));

    assertThatThrownBy(() -> proxy.list(ACTOR_ID))
        .isInstanceOf(PermissionDeniedException.class)
        .hasMessageContaining("CATALOG_GLOBAL_READ");

    verify(realService, never()).list(any());
  }

  @Test
  @DisplayName("create() delega en el sujeto real cuando el permiso CATALOG_GLOBAL_WRITE es valido")
  void create_whenAuthorized_delegatesToRealService() {
    when(guard.require(ACTOR_ID, "CATALOG_GLOBAL_WRITE")).thenReturn(actor());
    VaccineRequest req = new VaccineRequest(
        "Polio", "POL", "PAI", (short) 3, 2, 60,
        false, false, false, false, false, false, false, false, false);
    VaccineResponse expected = new VaccineResponse(
        VACCINE_ID, "Polio", "POL", "PAI", (short) 3, 2, 60,
        false, false, false, false, false, false, false, false, false,
        true, 0L);
    when(realService.create(ACTOR_ID, req)).thenReturn(expected);

    VaccineResponse result = proxy.create(ACTOR_ID, req);

    assertThat(result).isSameAs(expected);
    verify(guard).require(ACTOR_ID, "CATALOG_GLOBAL_WRITE");
    verify(realService).create(ACTOR_ID, req);
  }

  @Test
  @DisplayName("create() bloquea y no invoca al sujeto real cuando falta CATALOG_GLOBAL_WRITE")
  void create_whenUnauthorized_blocksExecution() {
    when(guard.require(ACTOR_ID, "CATALOG_GLOBAL_WRITE"))
        .thenThrow(new PermissionDeniedException("Permiso insuficiente: CATALOG_GLOBAL_WRITE"));
    VaccineRequest req = new VaccineRequest(
        "Polio", "POL", "PAI", (short) 3, 2, 60,
        false, false, false, false, false, false, false, false, false);

    assertThatThrownBy(() -> proxy.create(ACTOR_ID, req))
        .isInstanceOf(PermissionDeniedException.class);

    verify(realService, never()).create(any(), any());
  }

  @Test
  @DisplayName("delete() bloquea al sujeto real cuando el actor no tiene permisos")
  void delete_whenUnauthorized_blocksExecution() {
    when(guard.require(ACTOR_ID, "CATALOG_GLOBAL_WRITE"))
        .thenThrow(new PermissionDeniedException("Permiso insuficiente: CATALOG_GLOBAL_WRITE"));

    assertThatThrownBy(() -> proxy.delete(ACTOR_ID, VACCINE_ID, 1L))
        .isInstanceOf(PermissionDeniedException.class);

    verify(realService, never()).delete(any(), any(), any(Long.class));
  }
}
