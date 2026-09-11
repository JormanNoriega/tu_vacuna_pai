package com.pai.api.identity.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public record CreateInstitutionAdminRequest(
        @NotBlank(message = "El correo es obligatorio.")
        @Email(message = "Ingresa un correo valido.")
        @Size(max = 255, message = "El correo no puede superar 255 caracteres.")
        String email,

        @NotBlank(message = "El nombre completo es obligatorio.")
        @Size(max = 200, message = "El nombre no puede superar 200 caracteres.")
        String fullName,

        @NotNull(message = "La institucion es obligatoria.") UUID institutionId,

        @NotBlank(message = "La contrasena temporal es obligatoria.")
        @Size(min = 8, max = 128, message = "La contrasena debe tener entre 8 y 128 caracteres.")
        String temporaryPassword,

        @NotNull(message = "operationId es obligatorio para reintentos idempotentes.")
        UUID operationId) {}
