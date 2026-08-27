package com.pai.api.catalog.dto;
import java.util.UUID;
public record InstitutionVaccineResponse(UUID id, UUID institutionId, UUID vaccineId, String name, String code, String category, boolean enabled, long version) {}
