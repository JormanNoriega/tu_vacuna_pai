package com.pai.api.identity.entity;

/**
 * Maquina de estados de una operacion de aprovisionamiento de identidad.
 *
 * <ul>
 *   <li>{@code PENDING}: registrada, a la espera de crear el auth.user.</li>
 *   <li>{@code AUTH_CREATED}: el auth.user existe (con {@code operation_id} en
 *       su app_metadata).</li>
 *   <li>{@code MIRROR_CREATED}/{@code ROLE_ASSIGNED}: pasos intermedios del
 *       espejo (reservados; hoy espejo y roles se escriben atomicamente).</li>
 *   <li>{@code COMPLETED}: espejo y roles creados.</li>
 *   <li>{@code COMPENSATING}: compensando un auth.user tras un fallo.</li>
 *   <li>{@code COMPENSATED}: el auth.user se elimino (hubo deleteAuthUser).</li>
 *   <li>{@code COMPENSATION_FAILED}: el deleteAuthUser fallo; reconciliable.</li>
 *   <li>{@code REJECTED}: nada se creo (email ya existia o rechazo 4xx).</li>
 *   <li>{@code UNCERTAIN}: resultado incierto (timeout/5xx); reconciliable por
 *       correlacion de {@code operation_id}.</li>
 * </ul>
 */
public enum ProvisioningOperationStatus {
  PENDING,
  AUTH_CREATED,
  MIRROR_CREATED,
  ROLE_ASSIGNED,
  COMPLETED,
  COMPENSATING,
  COMPENSATED,
  COMPENSATION_FAILED,
  REJECTED,
  UNCERTAIN
}
