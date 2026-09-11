package com.pai.api.identity.dto;

import java.util.UUID;

public record InstitutionResponse(UUID id, String code, String name, String status, short offlineWindowHours) {}
