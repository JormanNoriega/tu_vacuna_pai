package com.pai.api.patients.dto;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Alta de un paciente. El documento y el nombre son obligatorios; el resto del
 * perfil (demografia, contactos, direcciones, tutores y antecedentes) es
 * opcional. El documento viaja crudo: el backend lo normaliza y valida antes de
 * persistir.
 */
public record CreatePatientRequest(
        @NotBlank(message = "El tipo de documento es obligatorio.")
        String documentType,

        @NotBlank(message = "El numero de documento es obligatorio.")
        String documentNumber,

        @NotBlank(message = "El nombre es obligatorio.")
        @Size(max = 120, message = "El nombre no puede superar 120 caracteres.")
        String firstName,

        @NotBlank(message = "El apellido es obligatorio.")
        @Size(max = 120, message = "El apellido no puede superar 120 caracteres.")
        String lastName,

        @NotNull(message = "La fecha de nacimiento es obligatoria.")
        LocalDate birthDate,

        @NotBlank(message = "El sexo es obligatorio.")
        String sex,

        @Valid DemographicDto demographics,

        @Valid List<ContactDto> contacts,

        @Valid List<AddressDto> addresses,

        @Valid List<GuardianDto> guardians,

        @Valid List<MedicalHistoryDto> medicalHistories) {

    public record DemographicDto(
            @Size(max = 20, message = "El genero no puede superar 20 caracteres.")
            String gender,
            @Size(max = 80, message = "La etnia no puede superar 80 caracteres.")
            String ethnicity,
            @Size(max = 120, message = "La escolaridad no puede superar 120 caracteres.")
            String educationLevel) {
    }

    public record ContactDto(
            @NotBlank(message = "El tipo de contacto es obligatorio.") String type,
            @NotBlank(message = "El valor del contacto es obligatorio.")
            @Size(max = 120, message = "El contacto no puede superar 120 caracteres.")
            String value,
            boolean primary) {
    }

    public record AddressDto(
            @Size(max = 200, message = "La direccion no puede superar 200 caracteres.")
            String street,
            UUID municipalityId,
            UUID departmentId,
            UUID countryId,
            boolean primary) {
    }

    public record GuardianDto(
            @NotBlank(message = "El parentesco es obligatorio.") String relationship,
            @NotBlank(message = "El nombre del tutor es obligatorio.")
            @Size(max = 120, message = "El nombre del tutor no puede superar 120 caracteres.")
            String fullName,
            @Size(max = 20, message = "El tipo de documento no puede superar 20 caracteres.")
            String documentType,
            @Size(max = 20, message = "El documento no puede superar 20 caracteres.")
            String documentNumber,
            @Size(max = 20, message = "El telefono no puede superar 20 caracteres.")
            String phone) {
    }

    public record MedicalHistoryDto(
            @NotBlank(message = "El antecedente es obligatorio.")
            @Size(max = 200, message = "El antecedente no puede superar 200 caracteres.")
            String condition,
            LocalDate diagnosedAt,
            @Size(max = 500, message = "Las notas no pueden superar 500 caracteres.")
            String notes) {
    }
}
