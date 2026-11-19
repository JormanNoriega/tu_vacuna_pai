package com.pai.api.inventory.controller;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.inventory.service.CustodyWorkflowService;
import com.pai.api.shared.exceptions.GlobalExceptionHandler;
import com.pai.api.shared.security.AuthorizationService;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.*;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class CustodyWorkflowControllerTest {
  @Configuration @EnableMethodSecurity
  static class Config {
    @Bean CustodyWorkflowService service() { return mock(CustodyWorkflowService.class); }
    @Bean CustodyWorkflowController controller(CustodyWorkflowService service) { return new CustodyWorkflowController(service); }
    @Bean(name="authorization") AuthorizationService authorization() { return new AuthorizationService(); }
  }
  @Test void serverEnforcesAdministrativeAndOwnRoutesIndependently() throws Exception {
    try(var context=new AnnotationConfigApplicationContext(Config.class)) {
      var service=context.getBean(CustodyWorkflowService.class);
      var controller=context.getBean(CustodyWorkflowController.class);
      var user=mock(AuthorizedUser.class);
      UUID actor=UUID.randomUUID(),inst=UUID.randomUUID(),assignment=UUID.randomUUID(),id=UUID.randomUUID();
      when(user.getId()).thenReturn(actor);
      when(user.hasPermission(any())).thenAnswer(c->java.util.Arrays.asList("ATTENTION_CREATE").contains(c.getArgument(0)));
      var auth=UsernamePasswordAuthenticationToken.authenticated(user,"",List.of());
      SecurityContextHolder.getContext().setAuthentication(auth);
      controller.mine(auth,inst,assignment);
      verify(service).read(actor,inst,assignment,true);
      assertThatThrownBy(()->controller.read(auth,inst,assignment)).isInstanceOf(AccessDeniedException.class);
      assertThatThrownBy(()->controller.finalizeTransfer(auth,inst,assignment,
          new CustodyWorkflowController.EvidenceRequest(id,"Soporte"))).isInstanceOf(AccessDeniedException.class);
      when(user.hasPermission(any())).thenAnswer(c->java.util.Arrays.asList("INVENTORY_READ","INVENTORY_WRITE").contains(c.getArgument(0)));
      controller.read(auth,inst,assignment);
      verify(service).read(actor,inst,assignment,false);
      assertThatThrownBy(()->controller.link(auth,inst,assignment,
          new CustodyWorkflowController.LinkRequest(id,UUID.randomUUID(),"Soporte"))).isInstanceOf(AccessDeniedException.class);
      assertThatThrownBy(()->controller.mine(auth,inst,assignment)).isInstanceOf(AccessDeniedException.class);
      when(user.hasPermission(any())).thenReturn(true);
      var mvc=MockMvcBuilders.standaloneSetup(controller).setControllerAdvice(new GlobalExceptionHandler()).build();
      mvc.perform(post("/api/v1/institutions/"+inst+"/inventory/my-assignments/"+assignment+"/custody-counts")
          .principal(auth).contentType(MediaType.APPLICATION_JSON).content("""
          {"id":"%s","closedVials":-1,"openVials":0,"exhaustedVials":0,"discardedVials":0,"discardedDoses":0,"note":" "}
          """.formatted(id))).andExpect(status().isBadRequest());
      verify(service,never()).recordCount(any(),any(),any(),any());
    } finally { SecurityContextHolder.clearContext(); }
  }
}
