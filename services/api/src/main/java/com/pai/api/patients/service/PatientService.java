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
import com.pai.api.patients.entity.PatientAffiliationEntity;
import com.pai.api.patients.entity.PatientContactEntity;
import com.pai.api.patients.entity.PatientDemographicEntity;
import com.pai.api.patients.entity.PatientEntity;
import com.pai.api.patients.entity.PatientGuardianEntity;
import com.pai.api.patients.entity.PatientMedicalHistoryEntity;
import com.pai.api.patients.entity.PatientSpecialConditionEntity;
import com.pai.api.patients.entity.PatientUserConditionEntity;
import com.pai.api.patients.exception.PatientAlreadyExistsException;
import com.pai.api.patients.exception.PatientNotFoundException;
import com.pai.api.patients.repository.PatientAddressRepository;
import com.pai.api.patients.repository.PatientAffiliationRepository;
import com.pai.api.patients.repository.PatientContactRepository;
import com.pai.api.patients.repository.PatientDemographicRepository;
import com.pai.api.patients.repository.PatientGuardianRepository;
import com.pai.api.patients.repository.PatientMedicalHistoryRepository;
import com.pai.api.patients.repository.PatientRepository;
import com.pai.api.patients.repository.PatientSpecialConditionRepository;
import com.pai.api.patients.repository.PatientUserConditionRepository;
import com.pai.api.shared.util.DocumentNormalizer;
import com.pai.api.synchronization.service.ProcessedOperationsService;
import java.time.Instant;
import java.util.ArrayList;
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
    private final PatientAffiliationRepository affiliations;
    private final PatientSpecialConditionRepository specialConditions;
    private final PatientUserConditionRepository userConditions;
    private final IdentityService identity;
    private final DataScope dataScope;
    private final AuditService audit;
    private final ProcessedOperationsService processedOperations;

    public PatientService(
            PatientRepository patients,
            PatientContactRepository contacts,
            PatientDemographicRepository demographics,
            PatientAddressRepository addresses,
            PatientGuardianRepository guardians,
            PatientMedicalHistoryRepository medicalHistories,
            PatientAffiliationRepository affiliations,
            PatientSpecialConditionRepository specialConditions,
            PatientUserConditionRepository userConditions,
            IdentityService identity,
            DataScope dataScope,
            AuditService audit,
            ProcessedOperationsService processedOperations) {
        this.patients = patients;
        this.contacts = contacts;
        this.demographics = demographics;
        this.addresses = addresses;
        this.guardians = guardians;
        this.medicalHistories = medicalHistories;
        this.affiliations = affiliations;
        this.specialConditions = specialConditions;
        this.userConditions = userConditions;
        this.identity = identity;
        this.dataScope = dataScope;
        this.audit = audit;
        this.processedOperations = processedOperations;
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
        var previous = processedOperations.find(operationId, PatientResponse.class);
        if (previous.isPresent()) {
            return previous.get();
        }

        AuthorizedUser actor = identity.resolve(actorId);
        UUID institutionId = institution(actor);

        String documentType = DocumentNormalizer.normalizeType(request.documentType());
        String documentNumber = DocumentNormalizer.normalize(request.documentNumber());
        validateDocument(documentType, documentNumber);
        PatientEntity.Sex sex = parseSex(request.sex());

        if (patients.existsByInstitutionIdAndDocumentTypeAndDocumentNumber(
                institutionId, documentType, documentNumber)) {
            UUID existingId = patients
                    .findByInstitutionIdAndDocumentTypeAndDocumentNumber(institutionId, documentType, documentNumber)
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
                blankToNull(request.secondName()),
                blankToNull(request.secondLastName()),
                request.birthCountryId(),
                blankToNull(request.birthPlace()),
                normalizeUpper(request.migrationStatus()),
                request.gestationalAgeAtBirth(),
                normalizeUpper(request.vaccinationCardType()),
                Boolean.TRUE.equals(request.authorizeCalls()),
                Boolean.TRUE.equals(request.authorizeEmail()),
                now);
        patients.save(patient);

        saveDemographics(patient.getId(), request.demographics(), now);
        saveContacts(patient.getId(), request.contacts(), now);
        saveAddresses(patient.getId(), request.addresses(), now);
        saveGuardians(patient.getId(), request.guardians(), now);
        saveMedicalHistories(patient.getId(), request.medicalHistories(), now);
        saveAffiliation(patient.getId(), request.affiliation(), now);
        saveSpecialConditions(patient.getId(), request.specialConditions(), now);
        saveUserCondition(patient.getId(), request.userCondition(), now);

        PatientResponse response = toResponse(patient);
        audit.record(
                actor.getId(),
                institutionId,
                AuditAction.PATIENT_CREATED,
                RESOURCE_TYPE,
                patient.getId(),
                parseOperationId(operationId),
                response);
        processedOperations.record(operationId, "CREATE_PATIENT", patient.getId(), institutionId, request, response);
        return response;
    }

    @Transactional(readOnly = true)
    public PatientResponse get(UUID actorId, UUID patientId) {
        AuthorizedUser actor = identity.resolve(actorId);
        return toResponse(requireScoped(actor, patientId));
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
                    .map(patient -> List.of(toResponse(patient)))
                    .orElseGet(List::of);
        }
        return patients.findByInstitutionIdAndDocumentNumber(institutionId, normalizedNumber).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public PatientResponse updateContact(UUID actorId, UUID patientId, UpdatePatientContactRequest request) {
        AuthorizedUser actor = identity.resolve(actorId);
        PatientEntity patient = requireScoped(actor, patientId);
        Instant now = Instant.now();

        contacts.deleteByPatientId(patientId);
        addresses.deleteByPatientId(patientId);
        saveContactUpdates(patientId, request.contacts(), now);
        saveAddressUpdates(patientId, request.addresses(), now);

        PatientResponse response = toResponse(patient);
        audit.record(
                actor.getId(),
                patient.getInstitutionId(),
                AuditAction.PATIENT_CONTACT_UPDATED,
                RESOURCE_TYPE,
                patientId,
                null,
                response);
        return response;
    }

    @Transactional
    public PatientResponse updateIdentity(UUID actorId, UUID patientId, UpdatePatientIdentityRequest request) {
        AuthorizedUser actor = identity.resolve(actorId);
        PatientEntity patient = requireScoped(actor, patientId);
        Instant now = Instant.now();

        PatientEntity.Sex sex = parseSex(request.sex());
        patient.updateIdentity(request.firstName().trim(), request.lastName().trim(), request.birthDate(), sex, now);
        patients.save(patient);

        PatientResponse response = toResponse(patient);
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
        Instant now = Instant.now();

        String gender = normalizeGender(request.gender());
        demographics.findByPatientId(patientId).ifPresent(demographics::delete);
        demographics.save(new PatientDemographicEntity(
                patientId, gender, blankToNull(request.ethnicity()), blankToNull(request.educationLevel()), now));

        PatientResponse response = toResponse(patient);
        audit.record(
                actor.getId(),
                patient.getInstitutionId(),
                AuditAction.PATIENT_DEMOGRAPHICS_UPDATED,
                RESOURCE_TYPE,
                patientId,
                null,
                response);
        return response;
    }

    @Transactional
    public PatientResponse updateMedicalHistories(
            UUID actorId, UUID patientId, UpdatePatientMedicalHistoriesRequest request) {
        AuthorizedUser actor = identity.resolve(actorId);
        PatientEntity patient = requireScoped(actor, patientId);
        Instant now = Instant.now();

        medicalHistories.deleteByPatientId(patientId);
        for (UpdatePatientMedicalHistoriesRequest.MedicalHistoryDto dto : safe(request.medicalHistories())) {
            medicalHistories.save(new PatientMedicalHistoryEntity(
                    UUID.randomUUID(),
                    patientId,
                    dto.condition().trim(),
                    dto.diagnosedAt(),
                    blankToNull(dto.notes()),
                    now));
        }

        PatientResponse response = toResponse(patient);
        audit.record(
                actor.getId(),
                patient.getInstitutionId(),
                AuditAction.PATIENT_HISTORY_UPDATED,
                RESOURCE_TYPE,
                patientId,
                null,
                response);
        return response;
    }

    // ---------- helpers ----------

    private record IdentityChange(PatientResponse patient, String justification) {}

    private String normalizeGender(String raw) {
        String value = blankToNull(raw);
        if (value == null) {
            return null;
        }
        String upper = value.toUpperCase();
        if (!Set.of("FEMALE", "MALE", "OTHER", "TRANSGENDER", "INDETERMINATE").contains(upper)) {
            throw new IllegalArgumentException("Genero invalido. Usa FEMALE, MALE, OTHER, TRANSGENDER o INDETERMINATE.");
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
            throw new IllegalArgumentException("Sexo invalido. Usa MALE, FEMALE o INDETERMINATE.");
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
                blankToNull(dto.gender()),
                blankToNull(dto.ethnicity()),
                normalizeUpper(dto.sexualOrientation()),
                blankToNull(dto.educationLevel()),
                now));
    }

    private void saveAffiliation(UUID patientId, CreatePatientRequest.AffiliationDto dto, Instant now) {
        if (dto == null) {
            return;
        }
        if (blankToNull(dto.affiliationRegime()) == null && blankToNull(dto.insurer()) == null) {
            return;
        }
        affiliations.save(new PatientAffiliationEntity(
                patientId, normalizeUpper(dto.affiliationRegime()), blankToNull(dto.insurer()), now));
    }

    private void saveSpecialConditions(UUID patientId, CreatePatientRequest.SpecialConditionsDto dto, Instant now) {
        if (dto == null) {
            return;
        }
        specialConditions.save(new PatientSpecialConditionEntity(
                patientId,
                Boolean.TRUE.equals(dto.displaced()),
                Boolean.TRUE.equals(dto.disabled()),
                Boolean.TRUE.equals(dto.deceased()),
                Boolean.TRUE.equals(dto.armedConflictVictim()),
                dto.currentlyStudying(),
                now));
    }

    private void saveUserCondition(UUID patientId, CreatePatientRequest.UserConditionDto dto, Instant now) {
        if (dto == null) {
            return;
        }
        userConditions.save(new PatientUserConditionEntity(
                patientId,
                normalizeUpper(dto.userCondition()),
                dto.lastMenstrualDate(),
                dto.gestationWeeks(),
                dto.probableDeliveryDate(),
                dto.previousPregnancies(),
                dto.hasGivenBirth(),
                blankToNull(dto.birthPlaceDelivery()),
                now));
    }

    private void saveContacts(UUID patientId, List<CreatePatientRequest.ContactDto> list, Instant now) {
        for (CreatePatientRequest.ContactDto dto : safe(list)) {
            contacts.save(new PatientContactEntity(
                    UUID.randomUUID(),
                    patientId,
                    parseContactType(dto.type()),
                    dto.value().trim(),
                    Boolean.TRUE.equals(dto.primary()),
                    normalizeUpper(dto.phoneKind()),
                    now));
        }
    }

    private void saveAddresses(UUID patientId, List<CreatePatientRequest.AddressDto> list, Instant now) {
        for (CreatePatientRequest.AddressDto dto : safe(list)) {
            addresses.save(new PatientAddressEntity(
                    UUID.randomUUID(),
                    patientId,
                    blankToNull(dto.street()),
                    dto.municipalityId(),
                    dto.departmentId(),
                    dto.countryId(),
                    blankToNull(dto.locality()),
                    normalizeUpper(dto.area()),
                    Boolean.TRUE.equals(dto.primary()),
                    now));
        }
    }

    private void saveGuardians(UUID patientId, List<CreatePatientRequest.GuardianDto> list, Instant now) {
        for (CreatePatientRequest.GuardianDto dto : safe(list)) {
            guardians.save(new PatientGuardianEntity(
                    UUID.randomUUID(),
                    patientId,
                    parseRelationship(dto.relationship()),
                    dto.fullName().trim(),
                    blankToNull(dto.secondName()),
                    blankToNull(dto.secondLastName()),
                    blankToNull(dto.documentType()),
                    DocumentNormalizer.normalize(dto.documentNumber()),
                    blankToNull(dto.phone()),
                    blankToNull(dto.landline()),
                    blankToNull(dto.cellphone()),
                    blankToNull(dto.email()),
                    normalizeUpper(dto.affiliationRegime()),
                    blankToNull(dto.insurer()),
                    normalizeUpper(dto.ethnicity()),
                    dto.displaced(),
                    now));
        }
    }

    private void saveMedicalHistories(UUID patientId, List<CreatePatientRequest.MedicalHistoryDto> list, Instant now) {
        for (CreatePatientRequest.MedicalHistoryDto dto : safe(list)) {
            medicalHistories.save(new PatientMedicalHistoryEntity(
                    UUID.randomUUID(),
                    patientId,
                    dto.condition().trim(),
                    dto.diagnosedAt(),
                    blankToNull(dto.notes()),
                    Boolean.TRUE.equals(dto.hasContraindication()),
                    blankToNull(dto.contraindicationDetails()),
                    Boolean.TRUE.equals(dto.hasPreviousReaction()),
                    blankToNull(dto.reactionDetails()),
                    blankToNull(dto.historyType()),
                    blankToNull(dto.specialObservations()),
                    now));
        }
    }

    private void saveContactUpdates(UUID patientId, List<UpdatePatientContactRequest.ContactDto> list, Instant now) {
        for (UpdatePatientContactRequest.ContactDto dto : safe(list)) {
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
        for (UpdatePatientContactRequest.AddressDto dto : safe(list)) {
            addresses.save(new PatientAddressEntity(
                    UUID.randomUUID(),
                    patientId,
                    blankToNull(dto.street()),
                    dto.municipalityId(),
                    dto.departmentId(),
                    dto.countryId(),
                    dto.primary(),
                    now));
        }
    }

    private <T> List<T> safe(List<T> list) {
        return list == null ? List.of() : list;
    }

    private String blankToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    /** Normaliza catalogos de referencia a su codigo en mayusculas. */
    private String normalizeUpper(String value) {
        String trimmed = blankToNull(value);
        return trimmed == null ? null : trimmed.toUpperCase();
    }

    private UUID parseOperationId(String operationId) {
        if (operationId == null || operationId.isBlank()) {
            return null;
        }
        try {
            return UUID.fromString(operationId.trim());
        } catch (IllegalArgumentException ex) {
            return null;
        }
    }

    private PatientResponse toResponse(PatientEntity patient) {
        PatientDemographicEntity demographic =
                demographics.findByPatientId(patient.getId()).orElse(null);

        PatientResponse.DemographicDto demographicDto = demographic == null
                ? null
                : new PatientResponse.DemographicDto(
                        demographic.getGender(),
                        demographic.getEthnicity(),
                        demographic.getSexualOrientation(),
                        demographic.getEducationLevel());

        List<PatientResponse.ContactDto> contactDtos = new ArrayList<>();
        for (PatientContactEntity contact : contacts.findByPatientIdOrderByCreatedAtAsc(patient.getId())) {
            contactDtos.add(new PatientResponse.ContactDto(
                    contact.getId(),
                    contact.getType(),
                    contact.getValue(),
                    contact.getPhoneKind(),
                    contact.isPrimary()));
        }

        List<PatientResponse.AddressDto> addressDtos = new ArrayList<>();
        for (PatientAddressEntity address : addresses.findByPatientIdOrderByCreatedAtAsc(patient.getId())) {
            addressDtos.add(new PatientResponse.AddressDto(
                    address.getId(),
                    address.getStreet(),
                    address.getMunicipalityId(),
                    address.getDepartmentId(),
                    address.getCountryId(),
                    address.getLocality(),
                    address.getArea(),
                    address.isPrimary()));
        }

        List<PatientResponse.GuardianDto> guardianDtos = new ArrayList<>();
        for (PatientGuardianEntity guardian : guardians.findByPatientIdOrderByCreatedAtAsc(patient.getId())) {
            guardianDtos.add(new PatientResponse.GuardianDto(
                    guardian.getId(),
                    guardian.getRelationship(),
                    guardian.getFullName(),
                    guardian.getSecondName(),
                    guardian.getSecondLastName(),
                    guardian.getDocumentType(),
                    guardian.getDocumentNumber(),
                    guardian.getPhone(),
                    guardian.getLandline(),
                    guardian.getCellphone(),
                    guardian.getEmail(),
                    guardian.getAffiliationRegime(),
                    guardian.getInsurer(),
                    guardian.getEthnicity(),
                    guardian.getDisplaced()));
        }

        List<PatientResponse.MedicalHistoryDto> historyDtos = new ArrayList<>();
        for (PatientMedicalHistoryEntity history :
                medicalHistories.findByPatientIdOrderByCreatedAtAsc(patient.getId())) {
            historyDtos.add(new PatientResponse.MedicalHistoryDto(
                    history.getId(),
                    history.getCondition(),
                    history.getDiagnosedAt(),
                    history.getNotes(),
                    history.isHasContraindication(),
                    history.getContraindicationDetails(),
                    history.isHasPreviousReaction(),
                    history.getReactionDetails(),
                    history.getHistoryType(),
                    history.getSpecialObservations()));
        }

        PatientResponse.AffiliationDto affiliationDto = affiliations.findByPatientId(patient.getId())
                .map(a -> new PatientResponse.AffiliationDto(a.getAffiliationRegime(), a.getInsurer()))
                .orElse(null);
        PatientResponse.SpecialConditionsDto specialDto = specialConditions.findByPatientId(patient.getId())
                .map(s -> new PatientResponse.SpecialConditionsDto(
                        s.isDisplaced(),
                        s.isDisabled(),
                        s.isDeceased(),
                        s.isArmedConflictVictim(),
                        s.getCurrentlyStudying()))
                .orElse(null);
        PatientResponse.UserConditionDto userDto = userConditions.findByPatientId(patient.getId())
                .map(u -> new PatientResponse.UserConditionDto(
                        u.getUserCondition(),
                        u.getLastMenstrualDate(),
                        u.getGestationWeeks(),
                        u.getProbableDeliveryDate(),
                        u.getPreviousPregnancies(),
                        u.getHasGivenBirth(),
                        u.getBirthPlaceDelivery()))
                .orElse(null);

        return new PatientResponse(
                patient.getId(),
                patient.getInstitutionId(),
                patient.getDocumentType(),
                patient.getDocumentNumber(),
                patient.getFirstName(),
                patient.getSecondName(),
                patient.getLastName(),
                patient.getSecondLastName(),
                patient.getBirthDate(),
                patient.getSex().name(),
                patient.getBirthCountryId(),
                patient.getBirthPlace(),
                patient.getMigrationStatus(),
                patient.getGestationalAgeAtBirth(),
                patient.getVaccinationCardType(),
                patient.isAuthorizeCalls(),
                patient.isAuthorizeEmail(),
                patient.getStatus().name(),
                patient.getVersion(),
                patient.getCreatedAt(),
                patient.getUpdatedAt(),
                demographicDto,
                contactDtos,
                addressDtos,
                guardianDtos,
                historyDtos,
                affiliationDto,
                specialDto,
                userDto);
    }
}
