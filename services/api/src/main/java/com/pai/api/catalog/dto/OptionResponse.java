package com.pai.api.catalog.dto;

import java.util.UUID;

public record OptionResponse(
    UUID id,
    UUID vaccineId,
    UUID institutionId,
    String fieldType,
    String value,
    String displayName,
    int sortOrder,
    boolean isDefault,
    boolean isActive,
    UUID sourceTemplateId,
    long version) {}
