package com.pai.api.identity.dto;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record UserResponse(
        UUID id,
        String email,
        String fullName,
        UUID institutionId,
        List<String> roles,
        String status,
        String documentType,
        String documentNumber,
        String phone,
        LocalDate birthDate,
        String gender,
        String professionCode,
        String professionalRegistrationNumber,
        String professionalRegistrationType) {

    /**
     * Constructor compacto (perfil sin campos ampliados), usado por operaciones
     * que no gestionan documento/contacto.
     */
    public UserResponse(UUID id, String email, String fullName, UUID institutionId,
            List<String> roles, String status) {
        this(id, email, fullName, institutionId, roles, status,
            null, null, null, null, null, null, null, null);
    }
}