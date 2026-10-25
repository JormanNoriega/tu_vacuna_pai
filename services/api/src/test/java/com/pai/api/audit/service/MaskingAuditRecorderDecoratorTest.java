package com.pai.api.audit.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import com.pai.api.audit.AuditAction;
import com.pai.api.audit.AuditRecord;
import com.pai.api.audit.AuditResourceType;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class MaskingAuditRecorderDecoratorTest {

  private AuditRecorder realRecorder;
  private MaskingAuditRecorderDecorator decorator;

  @BeforeEach
  void setUp() {
    realRecorder = mock(AuditRecorder.class);
    decorator = new MaskingAuditRecorderDecorator(realRecorder);
  }

  @Test
  @DisplayName("Debe enmascarar campos sensibles (password, token) y preservar campos no sensibles")
  void masksSensitiveKeysInPayload() {
    Map<String, Object> payload = new HashMap<>();
    payload.put("email", "admin@hospital.gov.co");
    payload.put("password", "SuperSecret123!");
    payload.put("accessToken", "eyJhbGciOi...");
    payload.put("role", "SUPER_ADMIN");

    AuditRecord record = new AuditRecord(
        UUID.randomUUID(),
        UUID.randomUUID(),
        AuditAction.PATIENT_CREATED,
        AuditResourceType.PATIENT,
        UUID.randomUUID(),
        UUID.randomUUID(),
        payload);

    decorator.record(record);

    ArgumentCaptor<AuditRecord> captor = ArgumentCaptor.forClass(AuditRecord.class);
    verify(realRecorder).record(captor.capture());

    AuditRecord captured = captor.getValue();
    assertThat(captured.actorId()).isEqualTo(record.actorId());
    assertThat(captured.payload()).isInstanceOf(Map.class);

    @SuppressWarnings("unchecked")
    Map<String, Object> capturedPayload = (Map<String, Object>) captured.payload();
    assertThat(capturedPayload.get("email")).isEqualTo("admin@hospital.gov.co");
    assertThat(capturedPayload.get("password")).isEqualTo("******");
    assertThat(capturedPayload.get("accessToken")).isEqualTo("******");
    assertThat(capturedPayload.get("role")).isEqualTo("SUPER_ADMIN");
  }

  @Test
  @DisplayName("Debe enmascarar llaves anidadas sensibles en mapas")
  void masksNestedSensitiveKeys() {
    Map<String, Object> nested = new HashMap<>();
    nested.put("secret", "456Secret");
    nested.put("publicNote", "Nota publica");

    Map<String, Object> root = new HashMap<>();
    root.put("details", nested);

    AuditRecord record = new AuditRecord(
        UUID.randomUUID(),
        UUID.randomUUID(),
        AuditAction.ATTENTION_CREATED,
        AuditResourceType.ATTENTION,
        UUID.randomUUID(),
        null,
        root);

    decorator.record(record);

    ArgumentCaptor<AuditRecord> captor = ArgumentCaptor.forClass(AuditRecord.class);
    verify(realRecorder).record(captor.capture());

    @SuppressWarnings("unchecked")
    Map<String, Object> capturedRoot = (Map<String, Object>) captor.getValue().payload();
    @SuppressWarnings("unchecked")
    Map<String, Object> capturedNested = (Map<String, Object>) capturedRoot.get("details");

    assertThat(capturedNested.get("secret")).isEqualTo("******");
    assertThat(capturedNested.get("publicNote")).isEqualTo("Nota publica");
  }

  @Test
  @DisplayName("Debe delegar sin cambios cuando el payload es nulo")
  void passesNullPayloadUnchanged() {
    AuditRecord record = new AuditRecord(
        UUID.randomUUID(),
        UUID.randomUUID(),
        AuditAction.DOSE_REGISTERED,
        AuditResourceType.APPLIED_DOSE,
        UUID.randomUUID(),
        null,
        null);

    decorator.record(record);

    verify(realRecorder).record(record);
  }
}
