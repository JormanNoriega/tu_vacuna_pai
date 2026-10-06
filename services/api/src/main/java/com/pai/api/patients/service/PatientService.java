package com.pai.api.patients.service;

import com.pai.api.audit.AuditAction;
import com.pai.api.audit.AuditResourceType;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.patients.dto.CreatePatientRequest;
import com.pai.api.patients.dto.PatientResponse;
import com.pai.api.patients.dto.PatientSummaryResponse;
import com.pai.api.patients.dto.UpdatePatientContactRequest;
import com.pai.api.patients.dto.UpdatePatientDemographicsRequest;
import com.pai.api.patients.dto.UpdatePatientIdentityRequest;
import com.pai.api.patients.dto.UpdatePatientMedicalHistoriesRequest;
import com.pai.api.patients.entity.PatientEntity;
import com.pai.api.patients.entity.PatientExtendedProfile;
import com.pai.api.patients.exception.PatientAlreadyExistsException;
import com.pai.api.patients.exception.PatientNotFoundException;
import com.pai.api.patients.repository.PatientRepository;
import com.pai.api.shared.application.IdempotencyCoordinator;
import com.pai.api.shared.util.DocumentNormalizer;
import com.pai.api.shared.util.Strings;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Gestion clinica de pacientes. El alcance institucional se deriva del actor via
 * {@link DataScope}: el paciente pertenece a la institucion del actor y la
 * institucion nunca se confia al cliente (ADR-007).
 *
 * <p>Toda escritura registra auditoria en la misma transaccion y admite un
 * {@code operationId} opcional para idempotencia (D3), compartido con el
 * {@code /sync/push}. En el camino offline-first el alta recibe un
 * {@code patientId} (aggregate_id) generado por el cliente.
 *
 * <p>Sosten del refactor SOLID:
 * <ul>
 *   <li><b>SRP</b>: las sub-entidades se persisten/ensamblan en
 *       {@link PatientSubEntitiesWriter} y el mapeo en {@link PatientMapper}.</li>
 *   <li><b>SRP</b>: las reglas de negocio viven en {@link PatientRules} y el
 *       parseo/normalizacion en {@link PatientFieldParser}.</li>
 *   <li><b>OCP</b>: la ceremonia idempotencia + auditoria la ejecuta
 *       {@link IdempotencyCoordinator}; el servicio solo aporta el cuerpo.</li>
 *   <li><b>DRY</b>: los helpers {@code blankToNull} y {@code safe} vienen de
 *       {@link Strings}.</li>
 * </ul>
 */
@Service
public class PatientService {

  private final PatientRepository patients;
  private final IdentityService identity;
  private final DataScope dataScope;
  private final IdempotencyCoordinator coordinator;
  private final PatientSubEntitiesWriter subEntities;
  private final PatientMapper mapper;

  public PatientService(
      PatientRepository patients,
      IdentityService identity,
      DataScope dataScope,
      IdempotencyCoordinator coordinator,
      PatientSubEntitiesWriter subEntities,
      PatientMapper mapper) {
    this.patients = patients;
    this.identity = identity;
    this.dataScope = dataScope;
    this.coordinator = coordinator;
    this.subEntities = subEntities;
    this.mapper = mapper;
  }

  @Transactional
  public PatientResponse create(UUID actorId, String operationId, CreatePatientRequest request) {
    return create(actorId, operationId, null, request);
  }

  /**
   * Alta de paciente. Para el camino offline-first, {@code patientId} es el
   * {@code aggregate_id} generado por el cliente y el servidor lo respeta como
   * PK para que el pull reconcilie el mismo agregado; en el camino REST directo
   * llega {@code null} y el servidor genera el UUID.
   */
  @Transactional
  public PatientResponse create(
      UUID actorId, String operationId, UUID patientId, CreatePatientRequest request) {
    return coordinator.execute(
        operationId,
        "CREATE_PATIENT",
        PatientResponse.class,
        () -> {
          AuthorizedUser actor = identity.resolve(actorId);
          return new IdempotencyCoordinator.AuditContext(
              actor.getId(),
              institution(actor),
              AuditAction.PATIENT_CREATED,
              AuditResourceType.PATIENT);
        },
        () -> request,
        () -> {
          AuthorizedUser actor = identity.resolve(actorId);
          UUID institutionId = institution(actor);

          String documentType = DocumentNormalizer.normalizeType(request.documentType());
          String documentNumber = DocumentNormalizer.normalize(request.documentNumber());
          PatientRules.validateDocument(documentType, documentNumber);
          PatientRules.validateGuardianForMinor(request);
          PatientEntity.Sex sex = PatientFieldParser.sex(request.sex());

          if (patients.existsByInstitutionIdAndDocumentTypeAndDocumentNumber(
              institutionId, documentType, documentNumber)) {
            UUID existingId = patients
                .findByInstitutionIdAndDocumentTypeAndDocumentNumber(
                    institutionId, documentType, documentNumber)
                .map(PatientEntity::getId)
                .orElse(null);
            throw new PatientAlreadyExistsException(
                "Ya existe un paciente con ese documento en la institucion.", existingId);
          }

          Instant now = Instant.now();
          PatientEntity patient = new PatientEntity(
              patientId != null ? patientId : UUID.randomUUID(),
              institutionId,
              documentType,
              documentNumber,
              request.firstName().trim(),
              request.lastName().trim(),
              request.birthDate(),
              sex,
              now);
          patient.applyExtendedProfile(
              new PatientExtendedProfile(
                  Strings.blankToNull(request.secondName()),
                  Strings.blankToNull(request.secondLastName()),
                  request.birthCountryId(),
                  Strings.blankToNull(request.birthPlace()),
                  PatientFieldParser.normalizeUpper(request.migrationStatus()),
                  request.gestationalAgeAtBirth(),
                  PatientFieldParser.normalizeUpper(request.vaccinationCardType()),
                  Boolean.TRUE.equals(request.authorizeCalls()),
                  Boolean.TRUE.equals(request.authorizeEmail())),
              now);
          patients.save(patient);

          subEntities.saveAll(patient.getId(), request, now);

          return new IdempotencyCoordinator.WriteResult<>(
              patient.getId(), subEntities.assemble(patient));
        });
  }

  @Transactional(readOnly = true)
  public PatientResponse get(UUID actorId, UUID patientId) {
    AuthorizedUser actor = identity.resolve(actorId);
    return subEntities.assemble(requireScoped(actor, patientId));
  }

  /**
   * Busca pacientes por documento dentro de la institucion del actor. El
   * numero se normaliza antes de consultar. Con tipo de documento el resultado
   * es unico (0 o 1); sin tipo puede haber coincidencias en distintos tipos.
   *
   * <p>Devuelve la vista ligera ({@link PatientSummaryResponse}): no carga las
   * sub-entidades del agregado (ISP).
   */
  @Transactional(readOnly = true)
  public List<PatientSummaryResponse> search(
      UUID actorId, String documentType, String documentNumber) {
    AuthorizedUser actor = identity.resolve(actorId);
    UUID institutionId = institution(actor);
    String normalizedNumber = DocumentNormalizer.normalize(documentNumber);
    if (normalizedNumber == null) {
      throw new IllegalArgumentException("El numero de documento es obligatorio.");
    }
    String normalizedType = DocumentNormalizer.normalizeType(documentType);
    if (normalizedType != null) {
      return patients
          .findByInstitutionIdAndDocumentTypeAndDocumentNumber(
              institutionId, normalizedType, normalizedNumber)
          .map(patient -> List.of(mapper.toSummary(patient)))
          .orElseGet(List::of);
    }
    return patients.findByInstitutionIdAndDocumentNumber(institutionId, normalizedNumber).stream()
        .map(mapper::toSummary)
        .toList();
  }

  @Transactional
  public PatientResponse updateContact(
      UUID actorId, UUID patientId, UpdatePatientContactRequest request) {
    AuthorizedUser actor = identity.resolve(actorId);
    PatientEntity patient = requireScoped(actor, patientId);
    return coordinator.executeAudited(
        actor.getId(),
        patient.getInstitutionId(),
        AuditAction.PATIENT_CONTACT_UPDATED,
        AuditResourceType.PATIENT,
        patientId,
        () -> {
          Instant now = Instant.now();
          subEntities.replaceContact(patientId, request, now);
          return subEntities.assemble(patient);
        });
  }

  @Transactional
  public PatientResponse updateIdentity(
      UUID actorId, UUID patientId, UpdatePatientIdentityRequest request) {
    AuthorizedUser actor = identity.resolve(actorId);
    PatientEntity patient = requireScoped(actor, patientId);
    return coordinator.executeAudited(
        actor.getId(),
        patient.getInstitutionId(),
        AuditAction.PATIENT_IDENTITY_UPDATED,
        AuditResourceType.PATIENT,
        patientId,
        response -> new IdentityChange(response, request.justification()),
        () -> {
          Instant now = Instant.now();
          PatientEntity.Sex sex = PatientFieldParser.sex(request.sex());
          patient.updateIdentity(
              request.firstName().trim(), request.lastName().trim(), request.birthDate(), sex, now);
          patients.save(patient);
          return subEntities.assemble(patient);
        });
  }

  @Transactional
  public PatientResponse updateDemographics(
      UUID actorId, UUID patientId, UpdatePatientDemographicsRequest request) {
    AuthorizedUser actor = identity.resolve(actorId);
    PatientEntity patient = requireScoped(actor, patientId);
    return coordinator.executeAudited(
        actor.getId(),
        patient.getInstitutionId(),
        AuditAction.PATIENT_DEMOGRAPHICS_UPDATED,
        AuditResourceType.PATIENT,
        patientId,
        () -> {
          Instant now = Instant.now();
          subEntities.replaceDemographics(patientId, request, now);
          return subEntities.assemble(patient);
        });
  }

  @Transactional
  public PatientResponse updateMedicalHistories(
      UUID actorId, UUID patientId, UpdatePatientMedicalHistoriesRequest request) {
    AuthorizedUser actor = identity.resolve(actorId);
    PatientEntity patient = requireScoped(actor, patientId);
    return coordinator.executeAudited(
        actor.getId(),
        patient.getInstitutionId(),
        AuditAction.PATIENT_HISTORY_UPDATED,
        AuditResourceType.PATIENT,
        patientId,
        () -> {
          Instant now = Instant.now();
          subEntities.replaceMedicalHistories(patientId, request, now);
          return subEntities.assemble(patient);
        });
  }

  // ---------- helpers ----------

  private record IdentityChange(PatientResponse patient, String justification) {}

  private UUID institution(AuthorizedUser actor) {
    return dataScope.institutionOf(actor);
  }

  private PatientEntity requireScoped(AuthorizedUser actor, UUID patientId) {
    UUID institutionId = institution(actor);
    return patients
        .findByIdAndInstitutionId(patientId, institutionId)
        .orElseThrow(() ->
            new PatientNotFoundException("El paciente no existe o no pertenece a tu institucion."));
  }
}
