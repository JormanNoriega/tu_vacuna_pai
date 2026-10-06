package com.pai.api.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.pai.api.identity.support.IdentityTestFixtures;
import com.pai.api.shared.exceptions.ScopeViolationException;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class DataScopeTest {

  private static final UUID INSTITUTION_ID = UUID.randomUUID();
  private static final UUID OTHER_INSTITUTION_ID = UUID.randomUUID();

  private final DataScope dataScope = new DataScope();

  private AuthorizedUser restrictedActor() {
    return IdentityTestFixtures.adminInstitution(UUID.randomUUID(), INSTITUTION_ID);
  }

  private AuthorizedUser unrestrictedActor() {
    return IdentityTestFixtures.superAdmin(UUID.randomUUID(), INSTITUTION_ID);
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
    assertThatThrownBy(
            () -> dataScope.resolveInstitutionId(restrictedActor(), OTHER_INSTITUTION_ID))
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
    assertThatThrownBy(
            () -> dataScope.requireSameInstitution(restrictedActor(), OTHER_INSTITUTION_ID))
        .isInstanceOf(ScopeViolationException.class);
  }

  @Test
  void requireSameInstitution_skipsCheckForUnrestrictedActor() {
    dataScope.requireSameInstitution(unrestrictedActor(), OTHER_INSTITUTION_ID);
  }
}
