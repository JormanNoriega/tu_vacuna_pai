package com.pai.api.identity.support;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** Fixtures compartidas por los tests del modulo de identidad (DRY). */
public final class IdentityTestFixtures {

  private IdentityTestFixtures() {}

  /** Institucion activa con la ventana offline por defecto (72 h). */
  public static InstitutionEntity institution(UUID id) {
    Instant now = Instant.now();
    return new InstitutionEntity(
        id, "HOSP-A", "Hospital A", InstitutionEntity.Status.ACTIVE, (short) 72, now, now);
  }

  /** Actor {@code ADMIN_INSTITUTION}: alcance restringido, permiso USER_MANAGE. */
  public static AuthorizedUser adminInstitution(UUID actorId, UUID institutionId) {
    return actor(
        actorId,
        institutionId,
        "admin@hosp.a",
        "Admin Hospital A",
        List.of("ADMIN_INSTITUTION"),
        List.of("USER_MANAGE"));
  }

  /** Actor {@code SUPER_ADMIN}: alcance global, INSTITUTION_WRITE + USER_MANAGE. */
  public static AuthorizedUser superAdmin(UUID actorId, UUID institutionId) {
    return actor(
        actorId,
        institutionId,
        "super@admin.test",
        "Super Admin",
        List.of("SUPER_ADMIN"),
        List.of("INSTITUTION_WRITE", "USER_MANAGE"));
  }

  /** Actor con roles y permisos explicitos. */
  public static AuthorizedUser actor(
      UUID actorId,
      UUID institutionId,
      String email,
      String fullName,
      List<String> roles,
      List<String> permissions) {
    return new AuthorizedUser(
        actorId, email, fullName, institution(institutionId), roles, permissions, Instant.now());
  }
}
