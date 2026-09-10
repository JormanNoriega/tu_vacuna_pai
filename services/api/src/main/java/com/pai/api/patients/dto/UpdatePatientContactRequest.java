package com.pai.api.patients.dto;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

/**
 * Actualiza los datos de contacto del paciente (telefono, correo) y sus
 * direcciones. La identidad (nombres, fecha de nacimiento) se modifica por el
 * endpoint de identidad, que exige justificacion.
 */
public record UpdatePatientContactRequest(
        @Valid List<ContactDto> contacts,

        @Valid List<AddressDto> addresses) {

    public record ContactDto(
            @NotBlank(message = "El tipo de contacto es obligatorio.") String type,
            @NotBlank(message = "El valor del contacto es obligatorio.") String value,
            boolean primary) {
    }

    public record AddressDto(
            String street,
            UUID municipalityId,
            UUID departmentId,
            UUID countryId,
            boolean primary) {
    }
}
