package com.pai.api.identity.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Solicitud para crear un {@code VACCINATOR} en la institucion del actor
 * autenticado (ADMIN_INSTITUTION).
 *
 * <p>A diferencia de {@link CreateInstitutionAdminRequest}, no incluye
 * {@code institutionId}: el scope institucional se resuelve exclusivamente a
 * partir del usuario autenticado en el servicio (regla de oro: el servidor
 * nunca confia en valores del body para conceder acceso a datos).
 *
 * <p>{@code operationId} es la clave de idempotencia generada por el movil por
 * intencion de creacion y reenviada en reintentos (ver
 * {@code app.provisioning_operations}).
 *
 * <p>Los valores de {@code documentNumber} y {@code professionalRegistration*}
 * llegan crudos (con separadores o sin ellos) y se NORMALIZAN en el servicio
 * ({@code DocumentNormalizer}) antes de validar unicidad y persistir. El
 * {@code @Pattern} del DTO es solo una primera barrera; la autoridad final es
 * el backend despues de normalizar.
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
    String temporaryPassword,

    @NotNull(message = "operationId es obligatorio para reintentos idempotentes.")
    UUID operationId,

    @NotBlank(message = "El tipo de documento es obligatorio.")
    @Pattern(
        regexp = "(?i:CC|TI|CE|PASAPORTE)",
        message = "Tipo de documento invalido. Usa CC, TI, CE o PASAPORTE.")
    String documentType,

    @NotBlank(message = "El numero de documento es obligatorio.")
    @Size(max = 40, message = "El numero de documento no puede superar 40 caracteres.")
    String documentNumber,

    @Size(max = 20, message = "El telefono no puede superar 20 caracteres.")
    String phone,

    @JsonFormat(pattern = "yyyy-MM-dd") LocalDate birthDate,

    @Pattern(
        regexp = "(?i:FEMALE|MALE|OTHER)",
        message = "Genero invalido. Usa FEMALE, MALE u OTHER.")
    String gender,

    @NotBlank(message = "La profesion es obligatoria.")
    @Size(max = 50, message = "La profesion no puede superar 50 caracteres.")
    String professionCode,

    @Size(max = 60, message = "El registro profesional no puede superar 60 caracteres.")
    String professionalRegistrationNumber,

    @Size(max = 60, message = "El tipo de registro profesional no puede superar 60 caracteres.")
    String professionalRegistrationType) {

  /**
   * Constructor compacto para escenarios sin perfil ampliado (pruebas). En
   * produccion el movil siempre envia el perfil completo.
   */
  public CreateVaccinatorRequest(
      String email, String fullName, String temporaryPassword, UUID operationId) {
    this(
        email,
        fullName,
        temporaryPassword,
        operationId,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null);
  }
}
