package com.pai.api.identity.service;

import com.pai.api.shared.exceptions.ScopeViolationException;
import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * Mecanismo de alcance institucional equivalente a RLS en la capa de datos.
 *
 * <p>Deriva del {@link AuthorizedUser} el alcance efectivo (ver
 * {@link InstitutionScope}) y expone operaciones semanticas para que los
 * servicios no repitan la logica de permisos. La regla que implementa:
 *
 * <pre>
 * Controller -> actor -> Service -> DataScope -> Repository(institutionId) -> WHERE institution_id
 * </pre>
 *
 * <p>La institucion nunca se confia al cliente: para actores restringidos se
 * deriva exclusivamente del actor y cualquier solicitud de otra institucion se
 * rechaza. Para actores con {@code INSTITUTION_WRITE} (hoy SUPER_ADMIN) el
 * alcance es {@code unrestricted} y la institucion la decide cada caso de uso
 * con su permiso adicional.
 */
@Service
public class DataScope {

  /**
   * Devuelve el alcance efectivo del actor.
   */
  public InstitutionScope currentScope(AuthorizedUser actor) {
    if (actor.getPermissions().contains(IdentityPermissions.INSTITUTION_WRITE)) {
      return InstitutionScope.global();
    }
    return InstitutionScope.restricted(actor.getInstitution().getId());
  }

  /**
   * Resuelve la institucion sobre la que se ejecuta una operacion.
   *
   * <p>Para un actor restringido la institucion solicitada por el cliente
   * debe coincidir con la del actor; si no, se lanza
   * {@link ScopeViolationException}. Para un actor {@code unrestricted} se
   * acepta la institucion solicitada.
   */
  public UUID resolveInstitutionId(AuthorizedUser actor, UUID requestedInstitutionId) {
    InstitutionScope scope = currentScope(actor);
    if (scope.unrestricted()) {
      return requestedInstitutionId;
    }
    if (!scope.institutionId().equals(requestedInstitutionId)) {
      throw new ScopeViolationException(
          "No tienes permiso para consultar datos de otra institucion.");
    }
    return scope.institutionId();
  }

  /**
   * Resuelve la institucion propia del actor (su institucion) aplicando el
   * alcance. Atajo de {@link #resolveInstitutionId(AuthorizedUser, UUID)} para
   * el caso comun en que el recurso vive en la institucion del actor.
   */
  public UUID institutionOf(AuthorizedUser actor) {
    return resolveInstitutionId(actor, actor.getInstitution().getId());
  }

  /**
   * Valida que un recurso ya cargado pertenezca al alcance del actor.
   * Para actores {@code unrestricted} la validacion no aplica.
   */
  public void requireSameInstitution(AuthorizedUser actor, UUID targetInstitutionId) {
    InstitutionScope scope = currentScope(actor);
    if (scope.unrestricted()) {
      return;
    }
    if (!scope.institutionId().equals(targetInstitutionId)) {
      throw new ScopeViolationException(
          "No tienes permiso para acceder a recursos de otra institucion.");
    }
  }
}
