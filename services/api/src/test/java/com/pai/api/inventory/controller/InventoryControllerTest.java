package com.pai.api.inventory.controller;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.inventory.domain.VialTransfer;
import com.pai.api.inventory.service.InventoryService;
import com.pai.api.shared.exceptions.GlobalExceptionHandler;
import com.pai.api.shared.security.AuthorizationService;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class InventoryControllerTest {
  @Configuration
  @EnableMethodSecurity
  static class Config {
    @Bean InventoryService service() { return mock(InventoryService.class); }
    @Bean InventoryController controller(InventoryService service) { return new InventoryController(service); }
    @Bean(name = "authorization") AuthorizationService authorization() { return new AuthorizationService(); }
  }

  private final UUID institution = UUID.randomUUID();
  private final UUID actor = UUID.randomUUID();
  private AnnotationConfigApplicationContext context;
  private InventoryService service;
  private InventoryController controller;
  private MockMvc mvc;
  private Authentication auth;

  @BeforeEach
  void setUp() {
    context = new AnnotationConfigApplicationContext(Config.class);
    service = context.getBean(InventoryService.class);
    controller = context.getBean(InventoryController.class);
    mvc = MockMvcBuilders.standaloneSetup(controller).setControllerAdvice(new GlobalExceptionHandler()).build();
    authorize("INVENTORY_READ", "INVENTORY_WRITE");
  }

  private void authorize(String... permissions) {
    var user = mock(AuthorizedUser.class);
    when(user.getId()).thenReturn(actor);
    when(user.hasPermission(any())).thenAnswer(call -> List.of(permissions).contains(call.getArgument(0)));
    auth = UsernamePasswordAuthenticationToken.authenticated(user, "", List.of());
    SecurityContextHolder.getContext().setAuthentication(auth);
  }

  @AfterEach
  void tearDown() {
    SecurityContextHolder.clearContext();
    context.close();
  }

  private String base() { return "/api/v1/institutions/" + institution + "/inventory"; }

  @Test
  void newLotWithEntryValidatesAndRequiresWritePermission() throws Exception {
    UUID lot = UUID.randomUUID();
    UUID vaccine = UUID.randomUUID();
    UUID movement = UUID.randomUUID();
    when(service.createLotWithEntry(eq(actor), eq(institution), eq(lot), eq(vaccine), any(), any(),
        any(), eq(10), eq(movement), eq(4), any(), any())).thenReturn(lot);
    String body = """
        {"id":"%s","vaccineId":"%s","manufacturer":"F","lotNumber":"A",
         "expiresOn":"2028-01-01","dosesPerVial":10,"movementId":"%s","vials":4,
         "occurredAt":"2026-01-01T12:00:00Z","note":"Conteo"}
        """.formatted(lot, vaccine, movement);
    mvc.perform(post(base() + "/lots-with-entry").principal(auth).contentType(MediaType.APPLICATION_JSON)
        .content(body)).andExpect(status().isCreated());
    authorize("INVENTORY_READ");
    assertThatThrownBy(() -> controller.createLotWithEntry(auth, institution,
        new InventoryController.CreateLotWithEntryRequest(lot, vaccine, "F", "A",
            java.time.LocalDate.of(2028, 1, 1), 10, movement, 4, Instant.now(), "Conteo")))
        .isInstanceOf(AccessDeniedException.class);
  }

  @Test
  void lotAndEntryRequestsValidateAndUseAuthenticatedActor() throws Exception {
    UUID lot = UUID.randomUUID();
    UUID vaccine = UUID.randomUUID();
    UUID movement = UUID.randomUUID();
    when(service.createLot(eq(actor), eq(institution), eq(lot), eq(vaccine), any(), any(), any(), eq(10)))
        .thenReturn(lot);
    mvc.perform(post(base() + "/lots").principal(auth).contentType(MediaType.APPLICATION_JSON)
        .content("""
            {"id":"%s","vaccineId":"%s","manufacturer":"Fabricante","lotNumber":"A1",
             "expiresOn":"2028-01-01","dosesPerVial":10}
            """.formatted(lot, vaccine)))
        .andExpect(status().isCreated()).andExpect(jsonPath("$.id").value(lot.toString()));
    verify(service).createLot(eq(actor), eq(institution), eq(lot), eq(vaccine), eq("Fabricante"),
        eq("A1"), eq(java.time.LocalDate.of(2028, 1, 1)), eq(10));
    mvc.perform(post(base() + "/entries").principal(auth).contentType(MediaType.APPLICATION_JSON)
        .content("""
            {"movementId":"%s","lotId":"%s","vials":4,"occurredAt":"2026-01-01T12:00:00Z","note":"Conteo"}
            """.formatted(movement, lot)))
        .andExpect(status().isCreated());
    verify(service).recordEntry(actor, institution, movement, lot, 4, Instant.parse("2026-01-01T12:00:00Z"), "Conteo");
    mvc.perform(post(base() + "/entries").principal(auth).contentType(MediaType.APPLICATION_JSON)
        .content("""
            {"movementId":"%s","lotId":"%s","vials":0,"occurredAt":"2026-01-01T12:00:00Z","note":"Conteo"}
            """.formatted(movement, lot)))
        .andExpect(status().isBadRequest());
    verifyNoMoreInteractions(service);
  }

  @Test
  void listsAndDispatchUseInstitutionAndActor() throws Exception {
    UUID lot = UUID.randomUUID();
    UUID vaccinator = UUID.randomUUID();
    UUID movement = UUID.randomUUID();
    UUID assignment = UUID.randomUUID();
    when(service.listLots(actor, institution)).thenReturn(List.of());
    when(service.listAssignments(actor, institution)).thenReturn(List.of());
    when(service.dispatch(eq(actor), eq(institution), eq(movement), eq(assignment), eq(lot),
        eq(vaccinator), eq(2), any(), eq("Entrega"), org.mockito.ArgumentMatchers.isNull()))
        .thenReturn(new VialTransfer.Assignment(assignment, institution, lot, vaccinator, null, 2,
            VialTransfer.Status.IN_TRANSIT));
    mvc.perform(get(base() + "/lots").principal(auth)).andExpect(status().isOk());
    mvc.perform(get(base() + "/assignments").principal(auth)).andExpect(status().isOk());
    mvc.perform(post(base() + "/assignments").principal(auth).contentType(MediaType.APPLICATION_JSON)
        .content("""
            {"movementId":"%s","assignmentId":"%s","lotId":"%s","vaccinatorId":"%s",
             "vials":2,"occurredAt":"2026-01-01T12:00:00Z","note":"Entrega"}
            """.formatted(movement, assignment, lot, vaccinator)))
        .andExpect(status().isCreated()).andExpect(jsonPath("$.status").value("IN_TRANSIT"));
  }

  @Test
  void methodSecurityRejectsReadAndWriteWithoutTheirPermissions() {
    authorize("INVENTORY_READ");
    assertThatThrownBy(() -> controller.entry(auth, institution,
        new InventoryController.EntryRequest(UUID.randomUUID(), UUID.randomUUID(), 1, Instant.now(), "x")))
        .isInstanceOf(AccessDeniedException.class);
    authorize("INVENTORY_WRITE");
    assertThatThrownBy(() -> controller.lots(auth, institution)).isInstanceOf(AccessDeniedException.class);
    assertThatThrownBy(() -> controller.receive(auth, institution, UUID.randomUUID(),
        new InventoryController.ReceiveRequest(1))).isInstanceOf(AccessDeniedException.class);
    verifyNoInteractions(service);
  }

  @Test
  void vaccinatorCanConfirmOnlyThroughOwnAuthenticatedIdentity() throws Exception {
    authorize("ATTENTION_CREATE");
    UUID assignment = UUID.randomUUID();
    UUID lot = UUID.randomUUID();
    when(service.receive(actor, institution, assignment, 3)).thenReturn(
        new VialTransfer.Assignment(assignment, institution, lot, actor, null, 3, VialTransfer.Status.RECEIVED));
    mvc.perform(post(base() + "/assignments/" + assignment + "/receive").principal(auth)
        .contentType(MediaType.APPLICATION_JSON).content("{\"vials\":3}"))
        .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("RECEIVED"));
    verify(service).receive(actor, institution, assignment, 3);
  }
}
