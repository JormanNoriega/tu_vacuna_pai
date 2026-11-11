package com.pai.api.inventory.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.shared.exceptions.PermissionDeniedException;
import com.pai.api.shared.exceptions.ScopeViolationException;
import com.pai.api.shared.security.PermissionGuard;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.transaction.support.TransactionTemplate;

class InstallationKeyServiceTest {
  private final UUID institution = UUID.randomUUID(), actor = UUID.randomUUID(), installation = UUID.randomUUID();
  private JdbcTemplate db;
  private TransactionTemplate tx;
  private InstallationKeyService service;
  private InstallationRecoveryService recovery;

  @BeforeEach void setup() {
    var source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID() + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1", "sa", "");
    db = new JdbcTemplate(source);
    tx = new TransactionTemplate(new DataSourceTransactionManager(source));
    db.execute("CREATE SCHEMA app");
    db.execute("CREATE ALIAS clock_timestamp FOR 'com.pai.api.inventory.security.InstallationChallengeServiceTest.clockTimestamp'");
    db.execute("CREATE TABLE app.inventory_installations (id UUID PRIMARY KEY, institution_id UUID, vaccinator_id UUID)");
    db.execute("CREATE TABLE app.inventory_installation_keys (installation_id UUID PRIMARY KEY, institution_id UUID, vaccinator_id UUID, public_key VARBINARY, status VARCHAR, enrolled_at TIMESTAMP WITH TIME ZONE, revoked_at TIMESTAMP WITH TIME ZONE, revoked_by UUID, revocation_note VARCHAR)");
    db.execute("CREATE TABLE app.inventory_installation_proof_challenges (id UUID PRIMARY KEY, institution_id UUID, actor_id UUID, installation_id UUID, public_key VARBINARY, nonce VARBINARY, expires_at TIMESTAMP WITH TIME ZONE, consumed_at TIMESTAMP WITH TIME ZONE)");
    db.execute("CREATE TABLE app.inventory_installation_recovery_cases (id UUID PRIMARY KEY, institution_id UUID, installation_id UUID, vaccinator_id UUID, opened_by UUID, reason VARCHAR, status VARCHAR DEFAULT 'OPEN', UNIQUE(institution_id, installation_id))");
    db.execute("CREATE TABLE app.inventory_installation_reservations (id UUID PRIMARY KEY, institution_id UUID, installation_id UUID, vial_count INT)");
    db.execute("CREATE TABLE app.inventory_installation_recovery_reviews (id UUID PRIMARY KEY, institution_id UUID, case_id UUID, installation_id UUID, reservation_id UUID, observed_vials INT, reserved_vials_at_review INT, note VARCHAR, reviewed_by UUID, reviewed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)");
    db.execute("CREATE TABLE app.inventory_installation_recovery_replacements (case_id UUID PRIMARY KEY, institution_id UUID, old_installation_id UUID, replacement_installation_id UUID, vaccinator_id UUID, linked_by UUID, note VARCHAR)");
    db.execute("CREATE TABLE app.inventory_recovery_review_decisions (id UUID PRIMARY KEY, institution_id UUID, case_id UUID, review_id UUID, disposition VARCHAR, rationale VARCHAR, decided_by UUID)");
    db.execute("CREATE TABLE app.inventory_quarantined_installation_events (id UUID PRIMARY KEY, institution_id UUID, installation_id UUID, vaccinator_id UUID, sequence_number BIGINT, payload VARBINARY, payload_sha256 VARBINARY, signature VARBINARY, received_by UUID, status VARCHAR DEFAULT 'QUARANTINED', UNIQUE(institution_id, installation_id, sequence_number))");
    db.execute("CREATE TABLE app.inventory_quarantined_event_reviews (id UUID PRIMARY KEY, institution_id UUID, installation_id UUID, case_id UUID, event_id UUID, disposition VARCHAR, rationale VARCHAR, reviewed_by UUID, reviewed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)");
    db.execute("CREATE TABLE app.inventory_quarantined_event_access_audit (id UUID PRIMARY KEY, institution_id UUID, installation_id UUID, case_id UUID, event_id UUID, accessed_by UUID, reason VARCHAR)");
    db.update("INSERT INTO app.inventory_installations VALUES (?, ?, ?)", installation, institution, actor);
    var guard = mock(PermissionGuard.class);
    var profile = mock(AuthorizedUser.class);
    var entity = mock(InstitutionEntity.class);
    when(entity.getId()).thenReturn(institution);
    when(profile.getInstitution()).thenReturn(entity);
    when(guard.require(any(), any())).thenReturn(profile);
    service = new InstallationKeyService(db, guard, new DataScope(), new InstallationChallengeService(db));
    recovery = new InstallationRecoveryService(db, guard, new DataScope(), service);
  }

  @Test void enrollmentRequiresProofAndRevocationCannotBeUndone() throws Exception {
    var keys = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
    byte[] key = keys.getPublic().getEncoded();
    var challenge = tx.execute(s -> service.begin(actor, institution, installation, key));
    var signer = Signature.getInstance("Ed25519");
    signer.initSign(keys.getPrivate());
    signer.update(InstallationProof.message(institution, actor, installation, challenge.nonce()));
    byte[] signature = signer.sign();
    assertThat((Boolean) tx.execute(s -> service.complete(actor, institution, installation, challenge.id(), key, new byte[64]))).isFalse();
    assertThat((Boolean) tx.execute(s -> service.complete(actor, institution, installation, challenge.id(), key, signature))).isTrue();
    tx.executeWithoutResult(s -> service.revoke(actor, institution, installation, "Equipo perdido"));
    tx.executeWithoutResult(s -> service.revoke(actor, institution, installation, "Reintento"));
    assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_keys WHERE installation_id=?", String.class, installation)).isEqualTo("REVOKED");
    assertThatThrownBy(() -> tx.execute(s -> service.begin(actor, institution, installation, key))).isInstanceOf(IllegalArgumentException.class);
  }

  @Test void revocationInvalidatesPendingAndScopeIsEnforced() throws Exception {
    byte[] key = KeyPairGenerator.getInstance("Ed25519").generateKeyPair().getPublic().getEncoded();
    var challenge = tx.execute(s -> service.begin(actor, institution, installation, key));
    assertThatThrownBy(() -> tx.execute(s -> service.begin(UUID.randomUUID(), institution, installation, key))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> service.revoke(actor, UUID.randomUUID(), installation, "Motivo"))).isInstanceOf(ScopeViolationException.class);
    tx.executeWithoutResult(s -> service.revoke(actor, institution, installation, "Bloqueo preventivo"));
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_installation_proof_challenges WHERE id=? AND consumed_at IS NOT NULL", Integer.class, challenge.id())).isEqualTo(1);
    assertThatThrownBy(() -> tx.execute(s -> service.complete(actor, institution, installation, challenge.id(), key, new byte[64]))).isInstanceOf(IllegalArgumentException.class);
  }

  @Test void realPermissionGuardRejectsUnauthorizedEnrollmentAndRevocation() {
    var identity = mock(IdentityService.class);
    var denied = mock(AuthorizedUser.class);
    when(identity.resolve(actor)).thenReturn(denied);
    // Un permiso logistico no autoriza por si solo a leer contenido sensible.
    when(denied.hasPermission("INVENTORY_WRITE")).thenReturn(true);
    var guarded = new InstallationKeyService(db, new PermissionGuard(identity), new DataScope(),
        new InstallationChallengeService(db));
    assertThatThrownBy(() -> tx.execute(s -> guarded.begin(actor, institution, installation, new byte[] {1})))
        .isInstanceOf(PermissionDeniedException.class);
    assertThatThrownBy(() -> tx.execute(s -> guarded.complete(actor, institution, installation, UUID.randomUUID(), new byte[] {1}, new byte[64])))
        .isInstanceOf(PermissionDeniedException.class);
    when(denied.hasPermission("INVENTORY_WRITE")).thenReturn(false);
    assertThatThrownBy(() -> tx.executeWithoutResult(s -> guarded.revoke(actor, institution, installation, "Motivo")))
        .isInstanceOf(PermissionDeniedException.class);
    when(denied.hasPermission("INVENTORY_WRITE")).thenReturn(true);
    var guardedRecovery = new InstallationRecoveryService(db, new PermissionGuard(identity), new DataScope(), guarded);
    assertThatThrownBy(() -> tx.execute(s -> guardedRecovery.readQuarantinedPayload(actor, institution,
        UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), "Motivo"))).isInstanceOf(PermissionDeniedException.class);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_installation_keys", Integer.class)).isZero();
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_installation_proof_challenges", Integer.class)).isZero();
  }

  @Test void openingRecoveryRevokesButNeverTransfersOrReleasesReservations() throws Exception {
    UUID reservation = UUID.randomUUID(), caseId = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_installation_reservations VALUES (?, ?, ?, 4)", reservation, institution, installation);
    byte[] key = KeyPairGenerator.getInstance("Ed25519").generateKeyPair().getPublic().getEncoded();
    var challenge = tx.execute(s -> service.begin(actor, institution, installation, key));
    assertThat((UUID) tx.execute(s -> recovery.open(actor, institution, installation, caseId, "Equipo perdido"))).isEqualTo(caseId);
    assertThat((UUID) tx.execute(s -> recovery.open(actor, institution, installation, caseId, "Equipo perdido"))).isEqualTo(caseId);
    assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_keys WHERE installation_id=?", String.class, installation)).isEqualTo("REVOKED");
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_installation_proof_challenges WHERE id=? AND consumed_at IS NOT NULL", Integer.class, challenge.id())).isEqualTo(1);
    assertThat(db.queryForObject("SELECT vial_count FROM app.inventory_installation_reservations WHERE id=? AND installation_id=?", Integer.class, reservation, installation)).isEqualTo(4);
    assertThatThrownBy(() -> tx.execute(s -> recovery.open(actor, institution, installation, UUID.randomUUID(), "Otro motivo"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.execute(s -> recovery.open(actor, UUID.randomUUID(), installation, UUID.randomUUID(), "Motivo"))).isInstanceOf(ScopeViolationException.class);
  }

  @Test void failedRecoveryRollsBackRevocation() {
    UUID caseId = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_installation_recovery_cases (id, institution_id, installation_id, vaccinator_id, opened_by, reason) VALUES (?, ?, ?, ?, ?, ?)",
        caseId, institution, UUID.randomUUID(), actor, actor, "Otro caso");
    assertThatThrownBy(() -> tx.execute(s -> recovery.open(actor, institution, installation, caseId, "Equipo perdido")))
        .isInstanceOf(org.springframework.dao.DataIntegrityViolationException.class);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_installation_keys WHERE installation_id=?", Integer.class, installation)).isZero();
  }

  @Test void reviewDocumentsDiscrepancyWithoutChangingReservation() {
    UUID reservation = UUID.randomUUID(), caseId = UUID.randomUUID(), reviewId = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_installation_reservations VALUES (?, ?, ?, 4)", reservation, institution, installation);
    tx.executeWithoutResult(s -> recovery.open(actor, institution, installation, caseId, "Equipo perdido"));
    var review = tx.execute(s -> recovery.review(actor, institution, caseId, reviewId, reservation, 1, "Conteo parcial"));
    assertThat(review.reservedVialsAtReview()).isEqualTo(4);
    assertThat(review.observedVials()).isEqualTo(1);
    assertThat((InstallationRecoveryService.Review) tx.execute(s -> recovery.review(actor, institution, caseId, reviewId, reservation, 1, "Conteo parcial"))).isEqualTo(review);
    assertThat(recovery.listReviews(actor, institution, caseId)).hasSize(1);
    assertThatThrownBy(() -> tx.execute(s -> recovery.review(actor, institution, caseId, reviewId, reservation, 2, "Conteo parcial"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.execute(s -> recovery.review(actor, institution, caseId, UUID.randomUUID(), UUID.randomUUID(), 1, "Otro"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.execute(s -> recovery.review(actor, UUID.randomUUID(), caseId, UUID.randomUUID(), reservation, 1, "Otro"))).isInstanceOf(ScopeViolationException.class);
    assertThat(db.queryForObject("SELECT vial_count FROM app.inventory_installation_reservations WHERE id=? AND installation_id=?", Integer.class, reservation, installation)).isEqualTo(4);
    assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_recovery_cases WHERE id=?", String.class, caseId)).isEqualTo("OPEN");
  }

  @Test void replacementRequiresActiveKeyAndSameOwnerWithoutMovingReservations() {
    UUID caseId = UUID.randomUUID(), replacement = UUID.randomUUID(), reservation = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_installation_reservations VALUES (?, ?, ?, 4)", reservation, institution, installation);
    db.update("INSERT INTO app.inventory_installations VALUES (?, ?, ?)", replacement, institution, actor);
    tx.executeWithoutResult(s -> recovery.open(actor, institution, installation, caseId, "Equipo perdido"));
    assertThatThrownBy(() -> tx.execute(s -> recovery.linkReplacement(actor, institution, caseId, installation, "Revisado"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.execute(s -> recovery.linkReplacement(actor, institution, caseId, replacement, "Revisado"))).isInstanceOf(IllegalArgumentException.class);
    db.update("INSERT INTO app.inventory_installation_keys (installation_id, institution_id, vaccinator_id, status) VALUES (?, ?, ?, 'ACTIVE')", replacement, institution, actor);
    var result = tx.execute(s -> recovery.linkReplacement(actor, institution, caseId, replacement, "Revisado"));
    assertThat(result.installationId()).isEqualTo(replacement);
    assertThat((InstallationRecoveryService.Replacement) tx.execute(s -> recovery.linkReplacement(actor, institution, caseId, replacement, "Revisado"))).isEqualTo(result);
    assertThatThrownBy(() -> tx.execute(s -> recovery.linkReplacement(actor, institution, caseId, replacement, "Otro detalle"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.execute(s -> recovery.linkReplacement(actor, UUID.randomUUID(), caseId, replacement, "Revisado"))).isInstanceOf(ScopeViolationException.class);
    assertThat(db.queryForObject("SELECT vial_count FROM app.inventory_installation_reservations WHERE id=? AND installation_id=?", Integer.class, reservation, installation)).isEqualTo(4);
    assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_recovery_cases WHERE id=?", String.class, caseId)).isEqualTo("OPEN");
  }

  @Test void replacementRejectsAnotherVaccinator() {
    UUID caseId = UUID.randomUUID(), replacement = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_installations VALUES (?, ?, ?)", replacement, institution, UUID.randomUUID());
    tx.executeWithoutResult(s -> recovery.open(actor, institution, installation, caseId, "Equipo perdido"));
    assertThatThrownBy(() -> tx.execute(s -> recovery.linkReplacement(actor, institution, caseId, replacement, "Revisado"))).isInstanceOf(IllegalArgumentException.class);
  }

  @Test void closureAssessmentNeverTreatsReviewsAsProofOfNoLateEvents() {
    UUID caseId = UUID.randomUUID(), replacement = UUID.randomUUID(), reservation = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_installation_reservations VALUES (?, ?, ?, 4)", reservation, institution, installation);
    db.update("INSERT INTO app.inventory_installations VALUES (?, ?, ?)", replacement, institution, actor);
    db.update("INSERT INTO app.inventory_installation_keys (installation_id, institution_id, vaccinator_id, status) VALUES (?, ?, ?, 'ACTIVE')", replacement, institution, actor);
    tx.executeWithoutResult(s -> recovery.open(actor, institution, installation, caseId, "Equipo perdido"));
    var initial = recovery.assessClosure(actor, institution, caseId);
    assertThat(initial.reservations()).isEqualTo(1);
    assertThat(initial.withoutReview()).isEqualTo(1);
    assertThat(initial.closureAllowed()).isFalse();
    tx.executeWithoutResult(s -> recovery.review(actor, institution, caseId, UUID.randomUUID(), reservation, 4, "Conteo"));
    tx.executeWithoutResult(s -> recovery.linkReplacement(actor, institution, caseId, replacement, "Revisado"));
    var assessment = recovery.assessClosure(actor, institution, caseId);
    assertThat(assessment.withoutReview()).isZero();
    assertThat(assessment.replacementKeyActive()).isTrue();
    assertThat(assessment.lateEventsVerified()).isFalse();
    assertThat(assessment.closureAllowed()).isFalse();
    db.update("UPDATE app.inventory_installation_keys SET status='REVOKED' WHERE installation_id=?", replacement);
    assertThat(recovery.assessClosure(actor, institution, caseId).replacementKeyActive()).isFalse();
    assertThat(db.queryForObject("SELECT vial_count FROM app.inventory_installation_reservations WHERE id=?", Integer.class, reservation)).isEqualTo(4);
    assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_recovery_cases WHERE id=?", String.class, caseId)).isEqualTo("OPEN");
    assertThatThrownBy(() -> recovery.assessClosure(actor, UUID.randomUUID(), caseId)).isInstanceOf(ScopeViolationException.class);
  }

  @Test void documentedDecisionIsIdempotentAndCannotReleaseOrClose() {
    UUID caseId = UUID.randomUUID(), reservation = UUID.randomUUID(), reviewId = UUID.randomUUID(), decisionId = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_installation_reservations VALUES (?, ?, ?, 4)", reservation, institution, installation);
    tx.executeWithoutResult(s -> recovery.open(actor, institution, installation, caseId, "Equipo perdido"));
    tx.executeWithoutResult(s -> recovery.review(actor, institution, caseId, reviewId, reservation, 1, "Conteo"));
    var decision = tx.execute(s -> recovery.decideReview(actor, institution, caseId, reviewId, decisionId, "DOCUMENTED", "Acta institucional"));
    assertThat((InstallationRecoveryService.ReviewDecision) tx.execute(s -> recovery.decideReview(actor, institution, caseId, reviewId, decisionId, "DOCUMENTED", "Acta institucional"))).isEqualTo(decision);
    assertThatThrownBy(() -> tx.execute(s -> recovery.decideReview(actor, institution, caseId, reviewId, decisionId, "NEEDS_INVESTIGATION", "Acta institucional"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.execute(s -> recovery.decideReview(actor, institution, caseId, UUID.randomUUID(), UUID.randomUUID(), "DOCUMENTED", "Acta"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.execute(s -> recovery.decideReview(actor, UUID.randomUUID(), caseId, reviewId, UUID.randomUUID(), "DOCUMENTED", "Acta"))).isInstanceOf(ScopeViolationException.class);
    assertThat(db.queryForObject("SELECT vial_count FROM app.inventory_installation_reservations WHERE id=? AND installation_id=?", Integer.class, reservation, installation)).isEqualTo(4);
    assertThat(recovery.assessClosure(actor, institution, caseId).closureAllowed()).isFalse();
    assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_recovery_cases WHERE id=?", String.class, caseId)).isEqualTo("OPEN");
  }

  @Test void signedLateEventIsQuarantinedIdempotentlyAfterRevocation() throws Exception {
    var identity = mock(IdentityService.class);
    var profile = mock(AuthorizedUser.class);
    var entity = mock(InstitutionEntity.class);
    when(entity.getId()).thenReturn(institution);
    when(profile.getInstitution()).thenReturn(entity);
    when(profile.hasPermission("ATTENTION_CREATE")).thenReturn(true);
    when(identity.resolve(actor)).thenReturn(profile);
    var events = new QuarantinedInstallationEventService(db, new PermissionGuard(identity), new DataScope());
    var pair = KeyPairGenerator.getInstance("Ed25519").generateKeyPair();
    db.update("INSERT INTO app.inventory_installation_keys (installation_id, institution_id, vaccinator_id, public_key, status) VALUES (?, ?, ?, ?, 'REVOKED')",
        installation, institution, actor, pair.getPublic().getEncoded());
    UUID event = UUID.randomUUID();
    byte[] payload = "evento de prueba".getBytes(java.nio.charset.StandardCharsets.UTF_8);
    var signer = Signature.getInstance("Ed25519");
    signer.initSign(pair.getPrivate());
    signer.update(QuarantinedInstallationEventService.signingMessage(institution, actor, installation, event, 1, payload));
    byte[] signature = signer.sign();
    assertThat((UUID) tx.execute(s -> events.receive(actor, institution, installation, event, 1, payload, signature))).isEqualTo(event);
    assertThat((UUID) tx.execute(s -> events.receive(actor, institution, installation, event, 1, payload, signature))).isEqualTo(event);
    byte[] changed = "otro evento".getBytes(java.nio.charset.StandardCharsets.UTF_8);
    assertThatThrownBy(() -> tx.execute(s -> events.receive(actor, institution, installation, event, 1, changed, signature))).isInstanceOf(IllegalArgumentException.class);
    signer.initSign(pair.getPrivate());
    signer.update(QuarantinedInstallationEventService.signingMessage(institution, actor, installation, event, 1, changed));
    byte[] changedSignature = signer.sign();
    assertThatThrownBy(() -> tx.execute(s -> events.receive(actor, institution, installation, event, 1, changed, changedSignature))).isInstanceOf(IllegalArgumentException.class).hasMessageContaining("reutilizado");
    UUID otherEvent = UUID.randomUUID();
    signer.initSign(pair.getPrivate());
    signer.update(QuarantinedInstallationEventService.signingMessage(institution, actor, installation, otherEvent, 1, payload));
    byte[] otherSignature = signer.sign();
    assertThatThrownBy(() -> tx.execute(s -> events.receive(actor, institution, installation, otherEvent, 1, payload, otherSignature))).isInstanceOf(IllegalArgumentException.class).hasMessageContaining("Secuencia");
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_quarantined_installation_events WHERE status='QUARANTINED'", Integer.class)).isEqualTo(1);
    UUID caseId = UUID.randomUUID(), reviewId = UUID.randomUUID();
    tx.executeWithoutResult(s -> recovery.open(actor, institution, installation, caseId, "Equipo perdido"));
    assertThat(recovery.listCaseEvents(actor, institution, caseId)).singleElement().satisfies(e -> assertThat(e.id()).isEqualTo(event));
    var review = tx.execute(s -> recovery.reviewEvent(actor, institution, caseId, event, reviewId,
        "NEEDS_INVESTIGATION", "Sin evidencia de fecha"));
    assertThat((InstallationRecoveryService.EventReview) tx.execute(s -> recovery.reviewEvent(actor, institution, caseId, event, reviewId,
        "NEEDS_INVESTIGATION", "Sin evidencia de fecha"))).isEqualTo(review);
    assertThatThrownBy(() -> tx.execute(s -> recovery.reviewEvent(actor, institution, caseId, event, reviewId,
        "DOCUMENTED", "Sin evidencia de fecha"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.execute(s -> recovery.reviewEvent(actor, institution, caseId, UUID.randomUUID(), UUID.randomUUID(),
        "DOCUMENTED", "Motivo"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> recovery.listCaseEvents(actor, UUID.randomUUID(), caseId)).isInstanceOf(ScopeViolationException.class);
    assertThat(recovery.listEventReviews(actor, institution, caseId)).hasSize(1);
    assertThat(db.queryForObject("SELECT status FROM app.inventory_quarantined_installation_events WHERE id=?", String.class, event)).isEqualTo("QUARANTINED");
    assertThat(db.queryForObject("SELECT status FROM app.inventory_installation_recovery_cases WHERE id=?", String.class, caseId)).isEqualTo("OPEN");
    assertThat(recovery.assessClosure(actor, institution, caseId).closureAllowed()).isFalse();
    UUID accessId = UUID.randomUUID();
    byte[] read = tx.execute(s -> recovery.readQuarantinedPayload(actor, institution, caseId, event, accessId, "Revision institucional"));
    assertThat(read).containsExactly(payload);
    assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_quarantined_event_access_audit WHERE id=? AND accessed_by=?", Integer.class, accessId, actor)).isEqualTo(1);
    assertThatThrownBy(() -> tx.execute(s -> recovery.readQuarantinedPayload(actor, institution, caseId, event, accessId, "Revision institucional"))).isInstanceOf(org.springframework.dao.DataIntegrityViolationException.class);
    assertThatThrownBy(() -> tx.execute(s -> recovery.readQuarantinedPayload(actor, UUID.randomUUID(), caseId, event, UUID.randomUUID(), "Motivo"))).isInstanceOf(ScopeViolationException.class);
    assertThatThrownBy(() -> tx.execute(s -> recovery.readQuarantinedPayload(actor, institution, caseId, UUID.randomUUID(), UUID.randomUUID(), "Motivo"))).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> tx.execute(s -> recovery.readQuarantinedPayload(actor, institution, caseId, event, UUID.randomUUID(), " "))).isInstanceOf(IllegalArgumentException.class);
    assertThat(db.queryForObject("SELECT status FROM app.inventory_quarantined_installation_events WHERE id=?", String.class, event)).isEqualTo("QUARANTINED");
    assertThat(recovery.assessClosure(actor, institution, caseId).closureAllowed()).isFalse();
  }

  @Test void sensitiveReadAuditCommitsEvenIfCallerTransactionRollsBack() {
    UUID caseId = UUID.randomUUID(), eventId = UUID.randomUUID(), auditId = UUID.randomUUID();
    db.update("INSERT INTO app.inventory_installation_recovery_cases (id, institution_id, installation_id, vaccinator_id, opened_by, reason) VALUES (?, ?, ?, ?, ?, ?)",
        caseId, institution, installation, actor, actor, "Prueba");
    db.update("INSERT INTO app.inventory_quarantined_installation_events (id, institution_id, installation_id, vaccinator_id, sequence_number, payload, payload_sha256, signature, received_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        eventId, institution, installation, actor, 1L, new byte[] {1}, new byte[32], new byte[64], actor);
    try (var context = new org.springframework.context.annotation.AnnotationConfigApplicationContext()) {
      context.register(TransactionConfig.class);
      context.registerBean("transactionManager", org.springframework.transaction.PlatformTransactionManager.class,
          () -> new DataSourceTransactionManager(db.getDataSource()));
      context.registerBean(InstallationRecoveryService.class, () -> recovery);
      context.refresh();
      var proxied = context.getBean(InstallationRecoveryService.class);
      tx.executeWithoutResult(status -> {
        assertThat(proxied.readQuarantinedPayload(actor, institution, caseId, eventId, auditId, "Revision")).containsExactly(1);
        status.setRollbackOnly();
      });
      assertThat(db.queryForObject("SELECT count(*) FROM app.inventory_quarantined_event_access_audit WHERE id=?", Integer.class, auditId)).isEqualTo(1);
    }
  }

  @org.springframework.context.annotation.Configuration
  @org.springframework.transaction.annotation.EnableTransactionManagement
  static class TransactionConfig {}
}
