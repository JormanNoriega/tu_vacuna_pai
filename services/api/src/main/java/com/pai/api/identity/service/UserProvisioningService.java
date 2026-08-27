package com.pai.api.identity.service;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

import com.pai.api.identity.dto.CreateInstitutionAdminRequest;
import com.pai.api.identity.dto.CreateVaccinatorRequest;
import com.pai.api.identity.dto.UserResponse;
import com.pai.api.identity.entity.ProvisioningOperationEntity;
import com.pai.api.identity.entity.ProvisioningOperationStatus;
import com.pai.api.identity.repository.InstitutionRepository;
import com.pai.api.identity.repository.ProfessionRepository;
import com.pai.api.identity.repository.ProvisioningOperationRepository;
import com.pai.api.shared.exceptions.AuthUserProvisioningException;
import com.pai.api.shared.exceptions.EmailAlreadyExistsException;
import com.pai.api.shared.exceptions.InstitutionNotFoundException;
import com.pai.api.shared.exceptions.PermissionDeniedException;
import com.pai.api.shared.exceptions.ProvisioningPendingException;
import com.pai.api.shared.exceptions.UncertainProvisioningException;
import com.pai.api.shared.util.DocumentNormalizer;

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
 * <p>La institucion del vacunador se deriva exclusivamente del actor; la del
 * admin de institucion la decide el actor con {@code INSTITUTION_WRITE}.
 */
@Service
public class UserProvisioningService {

    private static final Logger log = LoggerFactory.getLogger(UserProvisioningService.class);

    private static final String ADMIN_INSTITUTION_ROLE = "ADMIN_INSTITUTION";
    private static final String VACCINATOR_ROLE = "VACCINATOR";
    private static final String USER_MANAGE_PERMISSION = "USER_MANAGE";
    private static final String INSTITUTION_WRITE_PERMISSION = "INSTITUTION_WRITE";

    private static final Set<ProvisioningOperationStatus> ADOPTABLE_FROM =
        Set.of(ProvisioningOperationStatus.PENDING, ProvisioningOperationStatus.UNCERTAIN);

    private final IdentityService identityService;
    private final InstitutionRepository institutionRepository;
    private final ProfessionRepository professionRepository;
    private final AuthUserProvisioningClient authUserClient;
    private final ProvisioningOperationRepository operationRepository;
    private final AuthUserLookupService authUserLookup;
    private final UserMirrorWriter mirrorWriter;

    public UserProvisioningService(IdentityService identityService,
            InstitutionRepository institutionRepository,
            ProfessionRepository professionRepository,
            AuthUserProvisioningClient authUserClient,
            ProvisioningOperationRepository operationRepository,
            AuthUserLookupService authUserLookup,
            UserMirrorWriter mirrorWriter) {
        this.identityService = identityService;
        this.institutionRepository = institutionRepository;
        this.professionRepository = professionRepository;
        this.authUserClient = authUserClient;
        this.operationRepository = operationRepository;
        this.authUserLookup = authUserLookup;
        this.mirrorWriter = mirrorWriter;
    }

    /**
     * Crea un {@code ADMIN_INSTITUTION} para la institucion indicada. Exclusivo
     * de {@code INSTITUTION_WRITE} (SUPER_ADMIN); el permiso se revalida aqui
     * como segunda barrera ademas del {@code @PreAuthorize} del controller.
     */
    public UserResponse createInstitutionAdmin(UUID actorId, String accessToken,
            CreateInstitutionAdminRequest request) {
        AuthorizedUser actor = identityService.resolve(actorId);
        if (!actor.getPermissions().contains(INSTITUTION_WRITE_PERMISSION)) {
            throw new PermissionDeniedException(
                "No tienes permiso para crear administradores de institucion.");
        }

        institutionRepository.findById(request.institutionId())
            .orElseThrow(() -> new InstitutionNotFoundException(
                "La institucion no existe."));

        return provision(actor, accessToken, request.operationId(),
            request.email(), request.fullName(), request.temporaryPassword(),
            request.institutionId(), ADMIN_INSTITUTION_ROLE, null);
    }

    /**
     * Crea un {@code VACCINATOR} en la institucion del actor autenticado.
     * Exclusivo de {@code USER_MANAGE} (ADMIN_INSTITUTION); el permiso se
     * revalida aqui como segunda barrera ademas del {@code @PreAuthorize}. El
     * {@code institutionId} nunca se recibe del cliente: se deriva del actor.
     *
     * <p>El documento se normaliza aqui (autoridad final) ANTES de comprobar
     * unicidad y persistir; la profesion debe existir en el catalogo
     * {@code app.professions}.
     */
    public UserResponse createVaccinator(UUID actorId, String accessToken,
            CreateVaccinatorRequest request) {
        AuthorizedUser actor = identityService.resolve(actorId);
        if (!actor.getPermissions().contains(USER_MANAGE_PERMISSION)) {
            throw new PermissionDeniedException(
                "No tienes permiso para crear vacunadores.");
        }

        String documentType = DocumentNormalizer.normalizeType(request.documentType());
        String documentNumber = DocumentNormalizer.normalize(request.documentNumber());
        if (!DocumentNormalizer.isValidForType(documentNumber, documentType)) {
            throw new IllegalArgumentException(
                "El numero de documento no es valido para el tipo seleccionado.");
        }

        String professionCode = normalizeProfessionCode(request.professionCode());
        if (!professionRepository.existsByCode(professionCode)) {
            throw new IllegalArgumentException(
                "La profesion seleccionada no esta configurada.");
        }

        AuthUserProfile profile = new AuthUserProfile(
            documentType,
            documentNumber,
            trimToNull(request.phone()),
            request.birthDate(),
            DocumentNormalizer.normalizeType(request.gender()),
            professionCode,
            DocumentNormalizer.normalize(request.professionalRegistrationNumber()),
            trimToNull(request.professionalRegistrationType()));

        return provision(actor, accessToken, request.operationId(),
            request.email(), request.fullName(), request.temporaryPassword(),
            actor.getInstitution().getId(), VACCINATOR_ROLE, profile);
    }

    /**
     * Flujo completo de aprovisionamiento para un actor ya autorizado.
     */
    @SuppressWarnings("null")
    private UserResponse provision(AuthorizedUser actor, String accessToken,
            UUID operationId, String rawEmail, String fullName,
            String temporaryPassword, UUID institutionId, String roleCode,
            AuthUserProfile profile) {

        String email = rawEmail.trim().toLowerCase();

        ProvisioningOperationEntity op = resolveOperation(operationId, email,
            fullName, institutionId, roleCode, actor.getId(), profile);
        if (op.getStatus() == ProvisioningOperationStatus.COMPLETED) {
            return replayResult(op);
        }

        // Fase remota (fuera de transaccion): garantizar el auth.user.
        UUID authUserId = op.getAuthUserId();
        if (authUserId == null) {
            if (op.getStatus() == ProvisioningOperationStatus.UNCERTAIN) {
                // Reintento tras timeout: resolver por metadata antes de recrear.
                authUserId = authUserLookup.findByOperation(operationId)
                    .map(AuthUserLookupService.AuthUserRecord::authUserId)
                    .orElse(null);
                if (authUserId != null) {
                    transition(op, ProvisioningOperationStatus.UNCERTAIN,
                        ProvisioningOperationStatus.AUTH_CREATED, authUserId, null);
                }
            }

            if (authUserId == null) {
                try {
                    authUserId = authUserClient.createAuthUser(
                        accessToken, operationId, email, temporaryPassword, fullName, profile);
                    int adopted = operationRepository.adoptAuthUser(operationId,
                        ADOPTABLE_FROM, authUserId, Instant.now());
                    if (adopted == 0) {
                        ProvisioningOperationEntity fresh =
                            operationRepository.findById(operationId).orElseThrow();
                        if (fresh.getStatus() == ProvisioningOperationStatus.COMPLETED) {
                            return replayResult(fresh);
                        }
                        op = fresh;
                        authUserId = op.getAuthUserId();
                    } else {
                        op.setAuthUserId(authUserId);
                        op.setStatus(ProvisioningOperationStatus.AUTH_CREATED);
                        op.setUpdatedAt(Instant.now());
                    }
                } catch (EmailAlreadyExistsException ex) {
                    // No se creo nada: estado REJECTED (no hay compensacion).
                    transition(op, ProvisioningOperationStatus.PENDING,
                        ProvisioningOperationStatus.REJECTED, null, ex.getMessage());
                    throw ex;
                } catch (AuthUserProvisioningException ex) {
                    transition(op, ProvisioningOperationStatus.PENDING,
                        ProvisioningOperationStatus.REJECTED, null, ex.getMessage());
                    throw ex;
                } catch (UncertainProvisioningException ex) {
                    // Timeout/5xx: el auth.user pudo crearse. Se marca UNCERTAIN y
                    // se intenta auto-recuperar por correlacion; si no hay
                    // evidencia, queda pendiente de reconciliacion.
                    transition(op, ProvisioningOperationStatus.PENDING,
                        ProvisioningOperationStatus.UNCERTAIN, null, ex.getMessage());
                    Optional<AuthUserLookupService.AuthUserRecord> existing =
                        authUserLookup.findByOperation(operationId);
                    if (existing.isPresent()) {
                        authUserId = existing.get().authUserId();
                        transition(op, ProvisioningOperationStatus.UNCERTAIN,
                            ProvisioningOperationStatus.AUTH_CREATED, authUserId, null);
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
            ProvisioningOperationEntity fresh =
                operationRepository.findById(operationId).orElseThrow();
            if (fresh.getStatus() == ProvisioningOperationStatus.COMPLETED) {
                return replayResult(fresh);
            }
            throw ex;
        } catch (RuntimeException ex) {
            compensate(op, accessToken, ex);
            throw ex;
        }
    }

    /**
     * Carga la operacion por {@code operationId} o la crea en {@code PENDING}.
     * Aplica las reglas de idempotencia de reintentos.
     */
    private ProvisioningOperationEntity resolveOperation(UUID operationId, String email,
            String fullName, UUID institutionId, String roleCode, UUID actorId,
            AuthUserProfile profile) {
        ProvisioningOperationEntity op = operationRepository.findById(operationId).orElse(null);
        if (op == null) {
            return startOperation(operationId, email, fullName, institutionId,
                roleCode, actorId, profile);
        }

        if (!op.getEmail().equals(email)) {
            throw new IllegalArgumentException(
                "La operacion ya fue registrada con otro correo.");
        }
        if (profile != null && op.getDocumentNumber() != null
                && !op.getDocumentNumber().equals(profile.documentNumber())) {
            throw new IllegalArgumentException(
                "La operacion ya fue registrada con otro documento.");
        }

        switch (op.getStatus()) {
            case COMPLETED -> {
                // Se repliega en provision() con el resultado ya persistido.
            }
            case REJECTED -> throw new EmailAlreadyExistsException(
                "Ya existe un usuario con ese correo.");
            case COMPENSATION_FAILED -> throw new ProvisioningPendingException(
                "La creacion quedo pendiente de compensacion. Revisa la reconciliacion.");
            case COMPENSATING -> throw new ProvisioningPendingException(
                "La operacion esta en proceso de compensacion.");
            case COMPENSATED -> {
                // El auth.user ya se borro: el correo quedo libre; se reintenta.
                op.setStatus(ProvisioningOperationStatus.PENDING);
                op.setAttempts((short) (op.getAttempts() + 1));
                op.setError(null);
                op.setAuthUserId(null);
                op.setUpdatedAt(Instant.now());
                operationRepository.save(op);
            }
            default -> {
                // PENDING, AUTH_CREATED, UNCERTAIN: se continua en provision().
            }
        }
        return op;
    }

    private ProvisioningOperationEntity startOperation(UUID operationId, String email,
            String fullName, UUID institutionId, String roleCode, UUID actorId,
            AuthUserProfile profile) {
        Instant now = Instant.now();
        ProvisioningOperationEntity op = new ProvisioningOperationEntity(
            operationId, null, email, fullName, institutionId, roleCode, actorId,
            ProvisioningOperationStatus.PENDING, (short) 1, null, now, now,
            profile == null ? null : profile.documentType(),
            profile == null ? null : profile.documentNumber(),
            profile == null ? null : profile.phone(),
            profile == null ? null : profile.birthDate(),
            profile == null ? null : profile.gender(),
            profile == null ? null : profile.professionCode(),
            profile == null ? null : profile.professionalRegistrationNumber(),
            profile == null ? null : profile.professionalRegistrationType());
        try {
            return operationRepository.save(op);
        } catch (DataIntegrityViolationException ex) {
            // Concurrencia: otro request inserto la misma operacion.
            ProvisioningOperationEntity existing =
                operationRepository.findById(operationId).orElseThrow();
            if (existing.getEmail().equals(email)) {
                return existing;
            }
            throw ex;
        }
    }

    /**
     * Compensacion: elimina el auth.user que quedo sin espejo. Corre despues del
     * rollback de la fase espejo, cuando ninguna fila de {@code app.users}
     * referencia al auth.user y la FK no bloquea el borrado.
     */
    private void compensate(ProvisioningOperationEntity op, String accessToken,
            RuntimeException original) {
        UUID authUserId = op.getAuthUserId();
        if (authUserId == null) {
            return;
        }
        boolean started = transition(op, ProvisioningOperationStatus.AUTH_CREATED,
            ProvisioningOperationStatus.COMPENSATING, authUserId, null);
        if (!started) {
            // Ya avanzo (p. ej. lo completo otro proceso): no hay que compensar.
            return;
        }
        try {
            authUserClient.deleteAuthUser(accessToken, authUserId);
            transition(op, ProvisioningOperationStatus.COMPENSATING,
                ProvisioningOperationStatus.COMPENSATED, authUserId, null);
        } catch (RuntimeException compensationEx) {
            log.error("No se pudo compensar el auth.user huerfano {}", authUserId,
                compensationEx);
            transition(op, ProvisioningOperationStatus.COMPENSATING,
                ProvisioningOperationStatus.COMPENSATION_FAILED, authUserId,
                compensationEx.getMessage());
            original.addSuppressed(compensationEx);
        }
    }

    /**
     * Reconstruye la respuesta de una operacion ya completada (replay
     * idempotente). Los roles de estas operaciones son unicos por diseno.
     */
    private UserResponse replayResult(ProvisioningOperationEntity op) {
        return new UserResponse(
            op.getAuthUserId(),
            op.getEmail(),
            op.getFullName(),
            op.getInstitutionId(),
            List.of(op.getRole()),
            "ACTIVE",
            op.getDocumentType(),
            op.getDocumentNumber(),
            op.getPhone(),
            op.getBirthDate(),
            op.getGender(),
            op.getProfessionCode(),
            op.getProfessionalRegistrationNumber(),
            op.getProfessionalRegistrationType());
    }

    private static String normalizeProfessionCode(String raw) {
        if (raw == null) {
            return null;
        }
        String s = raw.trim().toUpperCase();
        return s.isEmpty() ? null : s;
    }

    private static String trimToNull(String raw) {
        if (raw == null) {
            return null;
        }
        String s = raw.trim();
        return s.isEmpty() ? null : s;
    }

    /**
     * Transicion con guarda de estado. Devuelve false si el estado ya avanzo.
     */
    private boolean transition(ProvisioningOperationEntity op,
            ProvisioningOperationStatus from, ProvisioningOperationStatus to,
            UUID authUserId, String error) {
        int rows = operationRepository.transition(op.getOperationId(), from, to,
            authUserId, error, Instant.now());
        if (rows == 0) {
            return false;
        }
        op.setStatus(to);
        op.setAuthUserId(authUserId);
        op.setError(error);
        op.setUpdatedAt(Instant.now());
        return true;
    }
}