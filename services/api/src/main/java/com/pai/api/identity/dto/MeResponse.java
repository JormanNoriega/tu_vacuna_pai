package com.pai.api.identity.dto;

import java.util.List;
import java.util.UUID;

public class MeResponse {

    private final UUID id;
    private final String email;
    private final String fullName;
    private final InstitutionDto institution;
    private final List<String> roles;
    private final List<String> permissions;
    private final int offlineWindowHours;
    private final String lastOnlineValidation;

    public MeResponse(
            UUID id,
            String email,
            String fullName,
            InstitutionDto institution,
            List<String> roles,
            List<String> permissions,
            int offlineWindowHours,
            String lastOnlineValidation) {
        this.id = id;
        this.email = email;
        this.fullName = fullName;
        this.institution = institution;
        this.roles = roles;
        this.permissions = permissions;
        this.offlineWindowHours = offlineWindowHours;
        this.lastOnlineValidation = lastOnlineValidation;
    }

    public UUID getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getFullName() {
        return fullName;
    }

    public InstitutionDto getInstitution() {
        return institution;
    }

    public List<String> getRoles() {
        return roles;
    }

    public List<String> getPermissions() {
        return permissions;
    }

    public int getOfflineWindowHours() {
        return offlineWindowHours;
    }

    public String getLastOnlineValidation() {
        return lastOnlineValidation;
    }

    public static class InstitutionDto {
        private final UUID id;
        private final String code;
        private final String name;

        public InstitutionDto(UUID id, String code, String name) {
            this.id = id;
            this.code = code;
            this.name = name;
        }

        public UUID getId() {
            return id;
        }

        public String getCode() {
            return code;
        }

        public String getName() {
            return name;
        }
    }
}
