package com.pai.api.catalog.dto;

import java.util.UUID;

public record GeoMunicipalityResponse(UUID id, String code, String name, UUID departmentId) {}
