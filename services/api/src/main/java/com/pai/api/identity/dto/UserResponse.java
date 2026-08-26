package com.pai.api.identity.dto;

import java.util.List;
import java.util.UUID;

public record UserResponse(
        UUID id,
        String email,
        String fullName,
        UUID institutionId,
        List<String> roles,
        String status) {
}
