package com.pai.api.audit;

/**
 * Tipo de recurso afectado por una accion auditable. Reemplaza el {@code String}
 * libre que viajaba entre los emisores y el {@link
 * com.pai.api.audit.service.AuditRecorder}: agregar un recurso nuevo no exige
 * tocar el contrato, solo el enum.
 */
public enum AuditResourceType {
  PATIENT,
  ATTENTION,
  APPLIED_DOSE
}
