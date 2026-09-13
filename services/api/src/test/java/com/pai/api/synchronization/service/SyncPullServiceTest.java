package com.pai.api.synchronization.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.synchronization.dto.SyncPullResponse;
import com.pai.api.synchronization.entity.ProcessedOperationEntity;
import com.pai.api.synchronization.repository.ProcessedOperationRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Pageable;
import tools.jackson.databind.ObjectMapper;

class SyncPullServiceTest {

    private static final UUID ACTOR_ID = UUID.randomUUID();
    private static final UUID INSTITUTION_ID = UUID.randomUUID();

    private ProcessedOperationRepository repository;
    private IdentityService identity;
    private SyncPullService service;

    @BeforeEach
    void setUp() {
        repository = mock(ProcessedOperationRepository.class);
        identity = mock(IdentityService.class);
        service = new SyncPullService(repository, identity, new DataScope(), new ObjectMapper());
    }

    private AuthorizedUser actor() {
        InstitutionEntity institution = new InstitutionEntity(
                INSTITUTION_ID,
                "HOSP-A",
                "Hospital A",
                InstitutionEntity.Status.ACTIVE,
                (short) 72,
                Instant.now(),
                Instant.now());
        return new AuthorizedUser(
                ACTOR_ID,
                "vac@hosp.a",
                "Ana Vacunadora",
                institution,
                List.of("VACCINATOR"),
                List.of("PATIENT_READ"),
                Instant.now());
    }

    private ProcessedOperationEntity row(long sequence, Instant createdAt, UUID operationId) {
        ProcessedOperationEntity row = mock(ProcessedOperationEntity.class);
        when(row.getSyncSequence()).thenReturn(sequence);
        when(row.getCreatedAt()).thenReturn(createdAt);
        when(row.getOperationId()).thenReturn(operationId);
        when(row.getCommandType()).thenReturn("CREATE_PATIENT");
        when(row.getAggregateId()).thenReturn(UUID.randomUUID());
        when(row.getPayload()).thenReturn("{\"documentType\":\"CC\"}");
        return row;
    }

    @Test
    void pull_is_inclusive_on_sync_sequence() {
        UUID firstId = UUID.randomUUID();
        UUID secondId = UUID.randomUUID();
        Instant sameTimestamp = Instant.parse("2026-09-07T10:00:00Z");
        ProcessedOperationEntity first = row(42, sameTimestamp, firstId);
        ProcessedOperationEntity second = row(43, sameTimestamp, secondId);
        when(identity.resolve(ACTOR_ID)).thenReturn(actor());
        when(repository.findByInstitutionIdAndSyncSequenceGreaterThanOrderBySyncSequenceAsc(
                        eq(INSTITUTION_ID), eq(41L), any(Pageable.class)))
                .thenReturn(List.of(first, second));

        SyncPullResponse response = service.pull(ACTOR_ID, "41|2026-09-07T09:59:00Z", null);

        assertThat(response.operations()).hasSize(2);
        assertThat(response.nextCursor()).isEqualTo("43|2026-09-07T10:00:00Z");
        assertThat(response.operations().get(0).payload()).containsEntry("documentType", "CC");
        verify(repository)
                .findByInstitutionIdAndSyncSequenceGreaterThanOrderBySyncSequenceAsc(
                        eq(INSTITUTION_ID), eq(41L), any(Pageable.class));
    }

    @Test
    void pull_keeps_cursor_when_no_new_operations() {
        when(identity.resolve(ACTOR_ID)).thenReturn(actor());
        when(repository.findByInstitutionIdAndSyncSequenceGreaterThanOrderBySyncSequenceAsc(
                        eq(INSTITUTION_ID), eq(7L), any(Pageable.class)))
                .thenReturn(List.of());

        SyncPullResponse response = service.pull(ACTOR_ID, "7|2026-09-07T09:00:00Z", 100);

        assertThat(response.operations()).isEmpty();
        assertThat(response.nextCursor()).isEqualTo("7|2026-09-07T09:00:00Z");
    }

    @Test
    void pull_starts_from_zero_when_cursor_absent() {
        when(identity.resolve(ACTOR_ID)).thenReturn(actor());
        when(repository.findByInstitutionIdAndSyncSequenceGreaterThanOrderBySyncSequenceAsc(
                        eq(INSTITUTION_ID), eq(0L), any(Pageable.class)))
                .thenReturn(List.of());

        SyncPullResponse response = service.pull(ACTOR_ID, null, null);

        assertThat(response.nextCursor()).isEqualTo("0|");
    }
}
