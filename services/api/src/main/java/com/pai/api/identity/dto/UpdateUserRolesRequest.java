package com.pai.api.identity.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;

/**
 * Solicitud para reemplazar los roles de un usuario de la institucion. El rol
 * {@code SUPER_ADMIN} no se puede asignar por esta via: se valida en el servicio.
 */
public record UpdateUserRolesRequest(
        @NotEmpty(message = "Debe indicar al menos un rol.")
        List<@Valid @jakarta.validation.constraints.NotBlank(message = "Un rol no puede estar vacio.") String> roles) {}
