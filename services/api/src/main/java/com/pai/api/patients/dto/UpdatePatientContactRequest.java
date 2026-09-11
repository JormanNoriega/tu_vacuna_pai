package com.pai.api.patients.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;

/**
 * Actualiza los datos de contacto del paciente (telefono, correo) y sus
 * direcciones. La identidad (nombres, fecha de nacimiento) se modifica por el
 * endpoint de identidad, que exige justificacion.
 */
public record UpdatePatientContactRequest(
        @Valid List<ContactDto> contacts, @Valid List<AddressDto> addresses) {

    public record ContactDto(
            @NotBlank(message = "El tipo de contacto es obligatorio.")
            String type,

            @NotBlank(message = "El valor del contacto es obligatorio.")
            @Size(max = 120, message = "El contacto no puede superar 120 caracteres.")
            String value,

            boolean primary) {}

    public record AddressDto(
            @Size(max = 200, message = "La direccion no puede superar 200 caracteres.")
            String street,

            UUID municipalityId,
            UUID departmentId,
            UUID countryId,
            boolean primary) {}
}
