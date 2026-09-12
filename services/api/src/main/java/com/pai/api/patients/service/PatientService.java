package com.pai.api.patients.service;

import com.pai.api.audit.AuditAction;
import com.pai.api.audit.service.AuditService;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.patients.dto.CreatePatientRequest;
import com.pai.api.patients.dto.PatientResponse;
import com.pai.api.patients.dto.UpdatePatientContactRequest;
import com.pai.api.patients.dto.UpdatePatientDemographicsRequest;
import com.pai.api.patients.dto.UpdatePatientIdentityRequest;
import com.pai.api.patients.dto.UpdatePatientMedicalHistoriesRequest;
import com.pai.api.patients.entity.PatientAddressEntity;
import com.pai.api.patients.entity.PatientContactEntity;
import com.pai.api.patients.entity.PatientDemographicEntity;
import com.pai.api.patients.entity.PatientEntity;
import com.pai.api.patients.entity.PatientGuardianEntity;
import com.pai.api.patients.entity.PatientMedicalHistoryEntity;
import com.pai.api.patients.exception.PatientAlreadyExistsException;
import com.pai.api.patients.exception.PatientNotFoundException;
import com.pai.api.patients.repository.PatientAddressRepository;
import com.pai.api.patients.repository.PatientContactRepository;
import com.pai.api.patients.repository.PatientDemographicRepository;
import com.pai.api.patients.repository.PatientGuardianRepository;
import com.pai.api.patients.repository.PatientMedicalHistoryRepository;
import com.pai.api.patients.repository.PatientRepository;
import com.pai.api.shared.application.IdempotencyCoordinator;
import com.pai.api.shared.util.DocumentNormalizer;
import com.pai.api.shared.util.Strings;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Gestion clinica de pacientes. El alcance institucional se deriva del actor via
 * {@link DataScope}: el paciente pertenece a la institucion del actor y la
 * institucion nunca se confia al cliente (ADR-007).
 *
 * <p>Toda escritura registra auditoria en la misma transaccion y admite un
 * {@code operationId} opcional para idempotencia (D3), compartido con el futuro
 * {@code /sync/push}.
 *
 * <p>Sosten del refactor SOLID:
 * <ul>
 *   <li><b>SRP</b>: el mapeo entidad {@literal ->} DTO esta en {@link PatientMapper}.</li>
 *   <li><b>OCP</b>: la ceremonia idempotencia + auditoria la ejecuta
 *       {@link IdempotencyCoordinator}; el servicio solo aporta el cuerpo.</li>
 *   <li><b>DRY</b>: los helpers {@code blankToNull} y {@code safe} vienen de
 *       {@link Strings}.</li>
 * </ul>
 */
@Service
public class PatientService {

    private static final String RESOURCE_TYPE = "PATIENT";

    private final PatientRepository patients;
    private final PatientContactRepository contacts;
    private final PatientDemographicRepository demographics;
    private final PatientAddressRepository addresses;
    private final PatientGuardianRepository guardians;
    private final PatientMedicalHistoryRepository medicalHistories;
    private final IdentityService identity;
    private final DataScope dataScope;
    private final AuditService audit;
    private final IdempotencyCoordinator coordinator;
    private final PatientMapper mapper;

    public PatientService(
            PatientRepository patients,
            PatientContactRepository contacts,
            PatientDemographicRepository demographics,
            PatientAddressRepository addresses,
            PatientGuardianRepository guardians,
            PatientMedicalHistoryRepository medicalHistories,
            IdentityService identity,
            DataScope dataScope,
            AuditService audit,
            IdempotencyCoordinator coordinator,
            PatientMapper mapper) {
        this.patients = patients;
        this.contacts = contacts;
        this.demographics = demographics;
        this.addresses = addresses;
        this.guardians = guardians;
        this.medicalHistories = medicalHistories;
        this.identity = identity;
        this.dataScope = dataScope;
        this.audit = audit;
        this.coordinator = coordinator;
        this.mapper = mapper;
    }

    @Transactional
    public PatientResponse create(UUID actorId, String operationId, CreatePatientRequest request) {
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
                            RESOURCE_TYPE);
                },
                () -> {
                    AuthorizedUser actor = identity.resolve(actorId);
                    UUID institutionId = institution(actor);

                    String documentType = DocumentNormalizer.normalizeType(request.documentType());
                    String documentNumber = DocumentNormalizer.normalize(request.documentNumber());
                    validateDocument(documentType, documentNumber);
                    PatientEntity.Sex sex = parseSex(request.sex());

                    if (patients.existsByInstitutionIdAndDocumentTypeAndDocumentNumber(
                            institutionId, documentType, documentNumber)) {
                        throw new PatientAlreadyExistsException(
                                "Ya existe un paciente con ese documento en la institucion.");
                    }

                    Instant now = Instant.now();
                    PatientEntity patient = patients.save(new PatientEntity(
                            UUID.randomUUID(),
                            institutionId,
                            documentType,
                            documentNumber,
                            request.firstName().trim(),
                            request.lastName().trim(),
                            request.birthDate(),
                            sex,
                            now));

                    saveDemographics(patient.getId(), request.demographics(), now);
                    saveContacts(patient.getId(), request.contacts(), now);
                    saveAddresses(patient.getId(), request.addresses(), now);
                    saveGuardians(patient.getId(), request.guardians(), now);
                    saveMedicalHistories(patient.getId(), request.medicalHistories(), now);

                    return new IdempotencyCoordinator.WriteResult<>(patient.getId(), response(patient));
                });
    }

    @Transactional(readOnly = true)
    public PatientResponse get(UUID actorId, UUID patientId) {
        AuthorizedUser actor = identity.resolve(actorId);
        return response(requireScoped(actor, patientId));
    }

    /**
     * Busca pacientes por documento dentro de la institucion del actor. El
     * numero se normaliza antes de consultar. Con tipo de documento el resultado
     * es unico (0 o 1); sin tipo puede haber coincidencias en distintos tipos.
     */
    @Transactional(readOnly = true)
    public List<PatientResponse> search(UUID actorId, String documentType, String documentNumber) {
        AuthorizedUser actor = identity.resolve(actorId);
        UUID institutionId = institution(actor);
        String normalizedNumber = DocumentNormalizer.normalize(documentNumber);
        if (normalizedNumber == null) {
            throw new IllegalArgumentException("El numero de documento es obligatorio.");
        }
        String normalizedType = DocumentNormalizer.normalizeType(documentType);
        if (normalizedType != null) {
            return patients.findByInstitutionIdAndDocumentTypeAndDocumentNumber(
                            institutionId, normalizedType, normalizedNumber)
                    .map(patient -> List.of(response(patient)))
                    .orElseGet(List::of);
        }
        return patients.findByInstitutionIdAndDocumentNumber(institutionId, normalizedNumber).stream()
                .map(this::response)
                .toList();
    }

    @Transactional
    public PatientResponse updateContact(UUID actorId, UUID patientId, UpdatePatientContactRequest request) {
        AuthorizedUser actor = identity.resolve(actorId);
        PatientEntity patient = requireScoped(actor, patientId);
        return coordinator.executeAudited(
                actor.getId(),
                patient.getInstitutionId(),
                AuditAction.PATIENT_CONTACT_UPDATED,
                RESOURCE_TYPE,
                patientId,
                () -> {
                    Instant now = Instant.now();
                    contacts.deleteByPatientId(patientId);
                    addresses.deleteByPatientId(patientId);
                    saveContactUpdates(patientId, request.contacts(), now);
                    saveAddressUpdates(patientId, request.addresses(), now);
                    return response(patient);
                });
    }

    @Transactional
    public PatientResponse updateIdentity(UUID actorId, UUID patientId, UpdatePatientIdentityRequest request) {
        AuthorizedUser actor = identity.resolve(actorId);
        PatientEntity patient = requireScoped(actor, patientId);
        Instant now = Instant.now();

        PatientEntity.Sex sex = parseSex(request.sex());
        patient.updateIdentity(request.firstName().trim(), request.lastName().trim(), request.birthDate(), sex, now);
        patients.save(patient);

        PatientResponse response = response(patient);
        audit.record(
                actor.getId(),
                patient.getInstitutionId(),
                AuditAction.PATIENT_IDENTITY_UPDATED,
                RESOURCE_TYPE,
                patientId,
                null,
                new IdentityChange(response, request.justification()));
        return response;
    }

    @Transactional
    public PatientResponse updateDemographics(UUID actorId, UUID patientId, UpdatePatientDemographicsRequest request) {
        AuthorizedUser actor = identity.resolve(actorId);
        PatientEntity patient = requireScoped(actor, patientId);
        return coordinator.executeAudited(
                actor.getId(),
                patient.getInstitutionId(),
                AuditAction.PATIENT_DEMOGRAPHICS_UPDATED,
                RESOURCE_TYPE,
                patientId,
                () -> {
                    Instant now = Instant.now();
                    String gender = normalizeGender(request.gender());
                    demographics.findByPatientId(patientId).ifPresent(demographics::delete);
                    demographics.save(new PatientDemographicEntity(
                            patientId,
                            gender,
                            Strings.blankToNull(request.ethnicity()),
                            Strings.blankToNull(request.educationLevel()),
                            now));
                    return response(patient);
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
                RESOURCE_TYPE,
                patientId,
                () -> {
                    Instant now = Instant.now();
                    medicalHistories.deleteByPatientId(patientId);
                    for (UpdatePatientMedicalHistoriesRequest.MedicalHistoryDto dto :
                            Strings.safe(request.medicalHistories())) {
                        medicalHistories.save(new PatientMedicalHistoryEntity(
                                UUID.randomUUID(),
                                patientId,
                                dto.condition().trim(),
                                dto.diagnosedAt(),
                                Strings.blankToNull(dto.notes()),
                                now));
                    }
                    return response(patient);
                });
    }

    // ---------- helpers ----------

    private record IdentityChange(PatientResponse patient, String justification) {}

    private String normalizeGender(String raw) {
        String value = Strings.blankToNull(raw);
        if (value == null) {
            return null;
        }
        String upper = value.toUpperCase();
        if (!Set.of("FEMALE", "MALE", "OTHER").contains(upper)) {
            throw new IllegalArgumentException("Genero invalido. Usa FEMALE, MALE u OTHER.");
        }
        return upper;
    }

    private UUID institution(AuthorizedUser actor) {
        return dataScope.resolveInstitutionId(actor, actor.getInstitution().getId());
    }

    private PatientEntity requireScoped(AuthorizedUser actor, UUID patientId) {
        UUID institutionId = institution(actor);
        return patients.findByIdAndInstitutionId(patientId, institutionId)
                .orElseThrow(
                        () -> new PatientNotFoundException("El paciente no existe o no pertenece a tu institucion."));
    }

    private void validateDocument(String documentType, String documentNumber) {
        if (documentType == null || documentNumber == null) {
            throw new IllegalArgumentException("El tipo y el numero de documento son obligatorios.");
        }
        if (!DocumentNormalizer.isValidForType(documentNumber, documentType)) {
            throw new IllegalArgumentException("El numero de documento no es valido para el tipo indicado.");
        }
    }

    private PatientEntity.Sex parseSex(String raw) {
        try {
            return PatientEntity.Sex.valueOf(raw.trim().toUpperCase());
        } catch (IllegalArgumentException | NullPointerException ex) {
            throw new IllegalArgumentException("Sexo invalido. Usa MALE o FEMALE.");
        }
    }

    private PatientContactEntity.Type parseContactType(String raw) {
        try {
            return PatientContactEntity.Type.valueOf(raw.trim().toUpperCase());
        } catch (IllegalArgumentException | NullPointerException ex) {
            throw new IllegalArgumentException("Tipo de contacto invalido.");
        }
    }

    private PatientGuardianEntity.Relationship parseRelationship(String raw) {
        try {
            return PatientGuardianEntity.Relationship.valueOf(raw.trim().toUpperCase());
        } catch (IllegalArgumentException | NullPointerException ex) {
            throw new IllegalArgumentException("Parentesco invalido. Usa MOTHER, FATHER, CAREGIVER u OTHER.");
        }
    }

    private void saveDemographics(UUID patientId, CreatePatientRequest.DemographicDto dto, Instant now) {
        if (dto == null) {
            return;
        }
        demographics.save(new PatientDemographicEntity(
                patientId,
                Strings.blankToNull(dto.gender()),
                Strings.blankToNull(dto.ethnicity()),
                Strings.blankToNull(dto.educationLevel()),
                now));
    }

    private void saveContacts(UUID patientId, List<CreatePatientRequest.ContactDto> list, Instant now) {
        for (CreatePatientRequest.ContactDto dto : Strings.safe(list)) {
            contacts.save(new PatientContactEntity(
                    UUID.randomUUID(),
                    patientId,
                    parseContactType(dto.type()),
                    dto.value().trim(),
                    dto.primary(),
                    now));
        }
    }

    private void saveAddresses(UUID patientId, List<CreatePatientRequest.AddressDto> list, Instant now) {
        for (CreatePatientRequest.AddressDto dto : Strings.safe(list)) {
            addresses.save(new PatientAddressEntity(
                    UUID.randomUUID(),
                    patientId,
                    Strings.blankToNull(dto.street()),
                    dto.municipalityId(),
                    dto.departmentId(),
                    dto.countryId(),
                    dto.primary(),
                    now));
        }
    }

    private void saveGuardians(UUID patientId, List<CreatePatientRequest.GuardianDto> list, Instant now) {
        for (CreatePatientRequest.GuardianDto dto : Strings.safe(list)) {
            guardians.save(new PatientGuardianEntity(
                    UUID.randomUUID(),
                    patientId,
                    parseRelationship(dto.relationship()),
                    dto.fullName().trim(),
                    Strings.blankToNull(dto.documentType()),
                    DocumentNormalizer.normalize(dto.documentNumber()),
                    Strings.blankToNull(dto.phone()),
                    now));
        }
    }

    private void saveMedicalHistories(UUID patientId, List<CreatePatientRequest.MedicalHistoryDto> list, Instant now) {
        for (CreatePatientRequest.MedicalHistoryDto dto : Strings.safe(list)) {
            medicalHistories.save(new PatientMedicalHistoryEntity(
                    UUID.randomUUID(),
                    patientId,
                    dto.condition().trim(),
                    dto.diagnosedAt(),
                    Strings.blankToNull(dto.notes()),
                    now));
        }
    }

    private void saveContactUpdates(UUID patientId, List<UpdatePatientContactRequest.ContactDto> list, Instant now) {
        for (UpdatePatientContactRequest.ContactDto dto : Strings.safe(list)) {
            contacts.save(new PatientContactEntity(
                    UUID.randomUUID(),
                    patientId,
                    parseContactType(dto.type()),
                    dto.value().trim(),
                    dto.primary(),
                    now));
        }
    }

    private void saveAddressUpdates(UUID patientId, List<UpdatePatientContactRequest.AddressDto> list, Instant now) {
        for (UpdatePatientContactRequest.AddressDto dto : Strings.safe(list)) {
            addresses.save(new PatientAddressEntity(
                    UUID.randomUUID(),
                    patientId,
                    Strings.blankToNull(dto.street()),
                    dto.municipalityId(),
                    dto.departmentId(),
                    dto.countryId(),
                    dto.primary(),
                    now));
        }
    }

    private PatientResponse response(PatientEntity patient) {
        return mapper.toResponse(
                patient,
                demographics.findByPatientId(patient.getId()).orElse(null),
                contacts.findByPatientIdOrderByCreatedAtAsc(patient.getId()),
                addresses.findByPatientIdOrderByCreatedAtAsc(patient.getId()),
                guardians.findByPatientIdOrderByCreatedAtAsc(patient.getId()),
                medicalHistories.findByPatientIdOrderByCreatedAtAsc(patient.getId()));
    }
}