package com.pai.api.identity.service;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Acceso de solo lectura a {@code auth.users} para correlacion de
 * aprovisionamiento, via RPCs {@code SECURITY DEFINER} en {@code public}. Spring
 * no necesita SELECT directo sobre el esquema {@code auth}; las RPCs exponen
 * solo la correlacion por {@code operation_id}.
 */
@Component
public class AuthUserLookupService {

  private final JdbcTemplate jdbcTemplate;

  public AuthUserLookupService(JdbcTemplate jdbcTemplate) {
    this.jdbcTemplate = jdbcTemplate;
  }

  /**
   * Devuelve el auth.user creado por una operacion, si existe. Vacio cuando
   * la operacion no creo nada (o aun no creo).
   */
  public Optional<AuthUserRecord> findByOperation(UUID operationId) {
    List<AuthUserRecord> rows = jdbcTemplate.query(
        "SELECT auth_user_id, email FROM public.find_auth_user_by_operation(?)",
        (rs, i) -> new AuthUserRecord(
            UUID.fromString(rs.getString("auth_user_id")), rs.getString("email")),
        operationId);
    return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
  }

  /**
   * Huerfanos de aprovisionamiento: auth.users con {@code operation_id} en
   * su app_metadata y sin espejo en {@code app.users}.
   */
  public List<OrphanRecord> listOrphans() {
    return jdbcTemplate.query(
        "SELECT operation_id, auth_user_id, email FROM public.list_provisioning_orphans()",
        (rs, i) -> new OrphanRecord(
            UUID.fromString(rs.getString("operation_id")),
            UUID.fromString(rs.getString("auth_user_id")),
            rs.getString("email")));
  }

  public record AuthUserRecord(UUID authUserId, String email) {}

  public record OrphanRecord(UUID operationId, UUID authUserId, String email) {}
}
