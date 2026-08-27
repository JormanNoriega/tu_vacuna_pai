package com.pai.api.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.shared.exceptions.ScopeViolationException;

class DataScopeTest {

    private static final UUID INSTITUTION_ID = UUID.randomUUID();
    private static final UUID OTHER_INSTITUTION_ID = UUID.randomUUID();

    private final DataScope dataScope = new DataScope();

    private AuthorizedUser restrictedActor() {
        return new AuthorizedUser(UUID.randomUUID(), "admin@hosp.a",
            "Admin Hospital A", institution(INSTITUTION_ID), List.of("ADMIN_INSTITUTION"),
            List.of("USER_MANAGE"), Instant.now());
    }

    private AuthorizedUser unrestrictedActor() {
        return new AuthorizedUser(UUID.randomUUID(), "super@admin.test",
            "Super Admin", institution(INSTITUTION_ID), List.of("SUPER_ADMIN"),
            List.of("INSTITUTION_WRITE", "USER_MANAGE"), Instant.now());
    }

    private InstitutionEntity institution(UUID id) {
        return new InstitutionEntity(id, "HOSP-A", "Hospital A",
            InstitutionEntity.Status.ACTIVE, (short) 72, Instant.now(), Instant.now());
    }

    @Test
    void currentScope_restrictsActorWithoutInstitutionWrite() {
        InstitutionScope scope = dataScope.currentScope(restrictedActor());

        assertThat(scope.unrestricted()).isFalse();
        assertThat(scope.institutionId()).isEqualTo(INSTITUTION_ID);
    }

    @Test
    void currentScope_isUnrestrictedForInstitutionWrite() {
        InstitutionScope scope = dataScope.currentScope(unrestrictedActor());

        assertThat(scope.unrestricted()).isTrue();
        assertThat(scope.institutionId()).isNull();
    }

    @Test
    void resolveInstitutionId_acceptsOwnInstitutionForRestrictedActor() {
        UUID resolved = dataScope.resolveInstitutionId(restrictedActor(), INSTITUTION_ID);

        assertThat(resolved).isEqualTo(INSTITUTION_ID);
    }

    @Test
    void resolveInstitutionId_rejectsOtherInstitutionForRestrictedActor() {
        assertThatThrownBy(() ->
            dataScope.resolveInstitutionId(restrictedActor(), OTHER_INSTITUTION_ID))
            .isInstanceOf(ScopeViolationException.class);
    }

    @Test
    void resolveInstitutionId_acceptsAnyInstitutionForUnrestrictedActor() {
        UUID resolved = dataScope.resolveInstitutionId(unrestrictedActor(), OTHER_INSTITUTION_ID);

        assertThat(resolved).isEqualTo(OTHER_INSTITUTION_ID);
    }

    @Test
    void requireSameInstitution_acceptsInScopeResource() {
        dataScope.requireSameInstitution(restrictedActor(), INSTITUTION_ID);
    }

    @Test
    void requireSameInstitution_rejectsOutOfScopeResource() {
        assertThatThrownBy(() ->
            dataScope.requireSameInstitution(restrictedActor(), OTHER_INSTITUTION_ID))
            .isInstanceOf(ScopeViolationException.class);
    }

    @Test
    void requireSameInstitution_skipsCheckForUnrestrictedActor() {
        dataScope.requireSameInstitution(unrestrictedActor(), OTHER_INSTITUTION_ID);
    }
}