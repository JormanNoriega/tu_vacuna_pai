package com.pai.api.catalog.dto;

import jakarta.validation.constraints.*;

public record OptionRequest(
    @NotBlank(message = "El tipo de campo es obligatorio.")
    @Size(max = 40, message = "El tipo de campo no puede superar 40 caracteres.")
    String fieldType,

    @NotBlank(message = "El valor es obligatorio.")
    @Size(max = 120, message = "El valor no puede superar 120 caracteres.")
    String value,

    @NotBlank(message = "El nombre visible es obligatorio.")
    @Size(max = 120, message = "El nombre visible no puede superar 120 caracteres.")
    String displayName,

    @Min(value = 0, message = "El orden no puede ser negativo.")
    @Max(value = 9999, message = "El orden no puede superar 9999.")
    int sortOrder,

    boolean isDefault,
    boolean isActive,
    long version) {}
