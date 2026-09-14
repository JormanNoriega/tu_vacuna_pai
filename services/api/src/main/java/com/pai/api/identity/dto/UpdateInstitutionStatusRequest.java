package com.pai.api.identity.dto;

import jakarta.validation.constraints.NotBlank;

public record UpdateInstitutionStatusRequest(
    @NotBlank(message = "El estado es obligatorio.") String status) {}
