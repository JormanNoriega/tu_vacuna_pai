package com.pai.api.identity.service;

import com.pai.api.identity.dto.CreateInstitutionAdminRequest;
import com.pai.api.identity.dto.CreateVaccinatorRequest;
import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.ProvisioningOperationStatus;
import com.pai.api.identity.exception.AuthUserProvisioningException;
import com.pai.api.identity.exception.EmailAlreadyExistsException;
import com.pai.api.identity.exception.InstitutionNotFoundException;
import com.pai.api.identity.exception.UncertainProvisioningException;
import com.pai.api.identity.repository.InstitutionRepository;
import com.pai.api.shared.security.PermissionGuard;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

/**
 * Orquestacion del aprovisionamiento de identidad. La creacion cruza dos
 * sistemas sin transaccion compartida (Supabase Auth via Edge Function y el
 * esquema {@code app}), por lo que cada intento se registra en
 * {@code app.provisioning_operations} con un {@code operationId} generado por
 * el movil (idempotencia) y se avanza por fases:
 *
 * <ol>
 *   <li><b>Fase remota</b> (fuera de cualquier transaccion): crea el auth.user
 *       con {@code operation_id} en su {@code app_metadata}. Un timeout/5xx no
 *       decide: la operacion queda {@code UNCERTAIN} y se resuelve por
 *       correlacion, nunca por email.</li>
 *   <li><b>Fase espejo</b> ({@link UserMirrorWriter}, transaccion corta): crea
 *       {@code app.users} + roles y marca {@code COMPLETED}. Si falla, la
 *       transaccion hace rollback y aqui se compensa ({@code deleteAuthUser})
 *       DESPUES del rollback, cuando la FK de {@code app.users} ya no bloquea
 *       el borrado.</li>
 * </ol>
 *
 * <p>El ciclo de vida del estado y las reglas de idempotencia viven en
 * {@link ProvisioningStateMachine}, y el perfil ampliado del vacunador en
 * {@link VaccinatorProfileFactory}; este servicio solo orquesta las fases.
 *
 * <p>La institucion del vacunador se deriva exclusivamente del actor; la del
 * admin de institucion la decide el actor con {@code INSTITUTION_WRITE}.
 */
@Service
public class UserProvisioningService {

  private static final Logger log = LoggerFactory.getLogger(UserProvisioningService.class);

  private final PermissionGuard guard;
  private final InstitutionRepository institutionRepository;
  private final AuthUserProvisioningClient authUserClient;
  private final AuthUserLookupService authUserLookup;
  private final UserMirrorWriter mirrorWriter;
  private final IdentityMapper mapper;
  private final ProvisioningStateMachine stateMachine;
  private final VaccinatorProfileFactory profileFactory;

  public UserProvisioningService(
      PermissionGuard guard,
      InstitutionRepository institutionRepository,
      AuthUserProvisioningClient authUserClient,
      AuthUserLookupService authUserLookup,
      UserMirrorWriter mirrorWriter,
      IdentityMapper mapper,
      ProvisioningStateMachine stateMachine,
      VaccinatorProfileFactory profileFactory) {
    this.guard = guard;
    this.institutionRepository = institutionRepository;
    this.authUserClient = authUserClient;
    this.authUserLookup = authUserLookup;
    this.mirrorWriter = mirrorWriter;
    this.mapper = mapper;
    this.stateMachine = stateMachine;
    this.profileFactory = profileFactory;
  }

  /**
   * Crea un {@code ADMIN_INSTITUTION} para la institucion indicada. Exclusivo
   * de {@code INSTITUTION_WRITE} (SUPER_ADMIN); el permiso se revalida aqui
   * como segunda barrera ademas del {@code @PreAuthorize} del controller.
   */
  public UserResponse createInstitutionAdmin(
      UUID actorId, String accessToken, CreateInstitutionAdminRequest request) {
    AuthorizedUser actor = guard.require(actorId, IdentityPermissions.INSTITUTION_WRITE);

    institutionRepository
        .findById(request.institutionId())
        .orElseThrow(() -> new InstitutionNotFoundException("La institucion no existe."));

    return provision(
        actor,
        accessToken,
        request.operationId(),
        request.email(),
        request.fullName(),
        request.temporaryPassword(),
        request.institutionId(),
        RoleCodes.ADMIN_INSTITUTION,
        null);
  }

  /**
   * Crea un {@code VACCINATOR} en la institucion del actor autenticado.
   * Exclusivo de {@code USER_MANAGE} (ADMIN_INSTITUTION); el permiso se
   * revalida aqui como segunda barrera ademas del {@code @PreAuthorize}. El
   * {@code institutionId} nunca se recibe del cliente: se deriva del actor.
   */
  public UserResponse createVaccinator(
      UUID actorId, String accessToken, CreateVaccinatorRequest request) {
    AuthorizedUser actor = guard.require(actorId, IdentityPermissions.USER_MANAGE);
    AuthUserProfile profile = profileFactory.create(request);

    return provision(
        actor,
        accessToken,
        request.operationId(),
        request.email(),
        request.fullName(),
        request.temporaryPassword(),
        actor.getInstitution().getId(),
        RoleCodes.VACCINATOR,
        profile);
  }

  /**
   * Flujo completo de aprovisionamiento para un actor ya autorizado.
   */
  private UserResponse provision(
      AuthorizedUser actor,
      String accessToken,
      UUID operationId,
      String rawEmail,
      String fullName,
      String temporaryPassword,
      UUID institutionId,
      String roleCode,
      AuthUserProfile profile) {

    String email = rawEmail.trim().toLowerCase();

    ProvisioningOperationEntity op = stateMachine.resolveOrStart(
        operationId, email, fullName, institutionId, roleCode, actor.getId(), profile);
    if (op.isCompleted()) {
      return replayResult(op);
    }

    // Fase remota (fuera de transaccion): garantizar el auth.user.
    UUID authUserId = op.getAuthUserId();
    if (authUserId == null) {
      if (op.getStatus() == ProvisioningOperationStatus.UNCERTAIN) {
        // Reintento tras timeout: resolver por metadata antes de recrear.
        authUserId = authUserLookup
            .findByOperation(operationId)
            .map(AuthUserLookupService.AuthUserRecord::authUserId)
            .orElse(null);
        if (authUserId != null) {
          stateMachine.transition(
              op,
              ProvisioningOperationStatus.UNCERTAIN,
              ProvisioningOperationStatus.AUTH_CREATED,
              authUserId,
              null);
        }
      }

      if (authUserId == null) {
        try {
          authUserId = authUserClient.createAuthUser(
              accessToken, operationId, email, temporaryPassword, fullName, profile);
          if (!stateMachine.adoptAuthUser(op, authUserId)) {
            ProvisioningOperationEntity fresh = stateMachine.find(operationId).orElseThrow();
            if (fresh.isCompleted()) {
              return replayResult(fresh);
            }
            op = fresh;
            authUserId = op.getAuthUserId();
          }
        } catch (EmailAlreadyExistsException ex) {
          // No se creo nada: estado REJECTED (no hay compensacion).
          stateMachine.transition(
              op,
              ProvisioningOperationStatus.PENDING,
              ProvisioningOperationStatus.REJECTED,
              null,
              ex.getMessage());
          throw ex;
        } catch (AuthUserProvisioningException ex) {
          stateMachine.transition(
              op,
              ProvisioningOperationStatus.PENDING,
              ProvisioningOperationStatus.REJECTED,
              null,
              ex.getMessage());
          throw ex;
        } catch (UncertainProvisioningException ex) {
          // Timeout/5xx: el auth.user pudo crearse. Se marca UNCERTAIN y
          // se intenta auto-recuperar por correlacion; si no hay
          // evidencia, queda pendiente de reconciliacion.
          stateMachine.transition(
              op,
              ProvisioningOperationStatus.PENDING,
              ProvisioningOperationStatus.UNCERTAIN,
              null,
              ex.getMessage());
          Optional<AuthUserLookupService.AuthUserRecord> existing =
              authUserLookup.findByOperation(operationId);
          if (existing.isPresent()) {
            authUserId = existing.get().authUserId();
            stateMachine.transition(
                op,
                ProvisioningOperationStatus.UNCERTAIN,
                ProvisioningOperationStatus.AUTH_CREATED,
                authUserId,
                null);
          } else {
            throw ex;
          }
        }
      }
    }

    // Fase espejo (tx corta) + compensacion post-rollback.
    try {
      return mirrorWriter.writeMirrorAndRoles(op, roleCode);
    } catch (DataIntegrityViolationException ex) {
      // Concurrencia: otra request o el reconciler ya creo el espejo.
      ProvisioningOperationEntity fresh = stateMachine.find(operationId).orElseThrow();
      if (fresh.isCompleted()) {
        return replayResult(fresh);
      }
      throw ex;
    } catch (RuntimeException ex) {
      compensate(op, accessToken, ex);
      throw ex;
    }
  }

  /**
   * Compensacion: elimina el auth.user que quedo sin espejo. Corre despues del
   * rollback de la fase espejo, cuando ninguna fila de {@code app.users}
   * referencia al auth.user y la FK no bloquea el borrado.
   */
  private void compensate(
      ProvisioningOperationEntity op, String accessToken, RuntimeException original) {
    UUID authUserId = op.getAuthUserId();
    if (authUserId == null) {
      return;
    }
    boolean started = stateMachine.transition(
        op,
        ProvisioningOperationStatus.AUTH_CREATED,
        ProvisioningOperationStatus.COMPENSATING,
        authUserId,
        null);
    if (!started) {
      // Ya avanzo (p. ej. lo completo otro proceso): no hay que compensar.
      return;
    }
    try {
      authUserClient.deleteAuthUser(accessToken, authUserId);
      stateMachine.transition(
          op,
          ProvisioningOperationStatus.COMPENSATING,
          ProvisioningOperationStatus.COMPENSATED,
          authUserId,
          null);
    } catch (RuntimeException compensationEx) {
      log.error("No se pudo compensar el auth.user huerfano {}", authUserId, compensationEx);
      stateMachine.transition(
          op,
          ProvisioningOperationStatus.COMPENSATING,
          ProvisioningOperationStatus.COMPENSATION_FAILED,
          authUserId,
          compensationEx.getMessage());
      original.addSuppressed(compensationEx);
    }
  }

  /**
   * Reconstruye la respuesta de una operacion ya completada (replay
   * idempotente). Los roles de estas operaciones son unicos por diseno.
   */
  private UserResponse replayResult(ProvisioningOperationEntity op) {
    return mapper.toUserResponse(op);
  }
}
