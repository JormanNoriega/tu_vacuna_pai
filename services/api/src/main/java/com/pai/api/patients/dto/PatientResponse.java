package com.pai.api.patients.dto;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Representacion completa de un paciente autorizado. */
public record PatientResponse(
        UUID id,
        UUID institutionId,
        String documentType,
        String documentNumber,
        String firstName,
        String lastName,
        LocalDate birthDate,
        String sex,
        String status,
        long version,
        Instant createdAt,
        Instant updatedAt,
        DemographicDto demographics,
        List<ContactDto> contacts,
        List<AddressDto> addresses,
        List<GuardianDto> guardians,
        List<MedicalHistoryDto> medicalHistories) {

    public record DemographicDto(String gender, String ethnicity, String educationLevel) {
    }

    public record ContactDto(UUID id, String type, String value, boolean primary) {
    }

    public record AddressDto(UUID id, String street, UUID municipalityId,
            UUID departmentId, UUID countryId, boolean primary) {
    }

    public record GuardianDto(UUID id, String relationship, String fullName,
            String documentType, String documentNumber, String phone) {
    }

    public record MedicalHistoryDto(UUID id, String condition, LocalDate diagnosedAt,
            String notes) {
    }
}
