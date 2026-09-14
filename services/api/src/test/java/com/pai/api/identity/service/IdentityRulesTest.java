package com.pai.api.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.entity.UserEntity;
import org.junit.jupiter.api.Test;

class IdentityRulesTest {

    @Test
    void parseUserStatus_normalizesCaseAndSpaces() {
        assertThat(IdentityRules.parseUserStatus(" inactive ")).isEqualTo(UserEntity.Status.INACTIVE);
        assertThat(IdentityRules.parseUserStatus("ACTIVE")).isEqualTo(UserEntity.Status.ACTIVE);
    }

    @Test
    void parseUserStatus_rejectsUnknownStatus() {
        assertThatThrownBy(() -> IdentityRules.parseUserStatus("SUSPENDED"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("Estado invalido. Usa ACTIVE o INACTIVE.");
    }

    @Test
    void parseInstitutionStatus_normalizesAndRejectsUnknown() {
        assertThat(IdentityRules.parseInstitutionStatus(" inactive ")).isEqualTo(InstitutionEntity.Status.INACTIVE);
        assertThatThrownBy(() -> IdentityRules.parseInstitutionStatus("X"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("Estado invalido. Usa ACTIVE o INACTIVE.");
    }
}