package com.pai.api.identity.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Solicitud para crear un {@code VACCINATOR} en la institucion del actor
 * autenticado (ADMIN_INSTITUTION).
 *
 * <p>A diferencia de {@link CreateInstitutionAdminRequest}, no incluye
 * {@code institutionId}: el scope institucional se resuelve exclusivamente a
 * partir del usuario autenticado en el servicio (regla de oro: el servidor
 * nunca confia en valores del body para conceder acceso a datos).
 */
public record CreateVaccinatorRequest(
        @NotBlank(message = "El correo es obligatorio.")
        @Email(message = "Ingresa un correo valido.")
        @Size(max = 255, message = "El correo no puede superar 255 caracteres.")
        String email,

        @NotBlank(message = "El nombre completo es obligatorio.")
        @Size(max = 200, message = "El nombre no puede superar 200 caracteres.")
        String fullName,

        @NotBlank(message = "La contrasena temporal es obligatoria.")
        @Size(min = 8, max = 128, message = "La contrasena debe tener entre 8 y 128 caracteres.")
        String temporaryPassword) {
}