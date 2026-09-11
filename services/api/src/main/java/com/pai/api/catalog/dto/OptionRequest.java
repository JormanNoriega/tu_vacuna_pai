package com.pai.api.catalog.dto;

import jakarta.validation.constraints.*;

public record OptionRequest(
        @NotBlank String fieldType,
        @NotBlank String value,
        @NotBlank String displayName,
        int sortOrder,
        boolean isDefault,
        boolean isActive,
        long version) {}
