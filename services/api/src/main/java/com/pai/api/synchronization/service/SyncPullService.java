package com.pai.api.synchronization.service;

import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityService;
import com.pai.api.synchronization.dto.SyncOperation;
import com.pai.api.synchronization.dto.SyncPullResponse;
import com.pai.api.synchronization.entity.ProcessedOperationEntity;
import com.pai.api.synchronization.repository.ProcessedOperationRepository;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import tools.jackson.databind.ObjectMapper;

/**
 * Entrega a {@code /sync/pull} las operaciones del scope del actor con
 * {@code sync_sequence} mayor al cursor. El cursor es compuesto
 * ({@code "{sync_sequence}|{created_at_iso}"}) y la comparacion es sobre
 * {@code sync_sequence} (nunca sobre {@code created_at}), de modo que dos
 * operaciones con el mismo timestamp no provocan saltos.
 *
 * <p>El scope se deriva del actor; el cliente nunca lo envia.
 */
@Service
public class SyncPullService {

  private static final int DEFAULT_LIMIT = 500;
  private static final int MAX_LIMIT = 1000;
  private static final String INITIAL_CURSOR = "0|";

  private final ProcessedOperationRepository repository;
  private final IdentityService identity;
  private final DataScope dataScope;
  private final ObjectMapper mapper;

  public SyncPullService(
      ProcessedOperationRepository repository,
      IdentityService identity,
      DataScope dataScope,
      ObjectMapper mapper) {
    this.repository = repository;
    this.identity = identity;
    this.dataScope = dataScope;
    this.mapper = mapper;
  }

  public SyncPullResponse pull(UUID actorId, String since, Integer limit) {
    AuthorizedUser actor = identity.resolve(actorId);
    UUID institutionId =
        dataScope.resolveInstitutionId(actor, actor.getInstitution().getId());
    long sequence = parseSequence(since);

    List<ProcessedOperationEntity> rows =
        repository.findByInstitutionIdAndSyncSequenceGreaterThanOrderBySyncSequenceAsc(
            institutionId, sequence, PageRequest.of(0, normalizeLimit(limit)));

    List<SyncOperation> operations = new ArrayList<>();
    for (ProcessedOperationEntity row : rows) {
      operations.add(new SyncOperation(
          row.getOperationId(),
          row.getCommandType(),
          row.getAggregateId(),
          readPayload(row.getPayload()),
          List.of()));
    }

    String nextCursor = rows.isEmpty() ? normalizeCursor(since) : cursor(rows.get(rows.size() - 1));
    return new SyncPullResponse(operations, nextCursor);
  }

  private long parseSequence(String since) {
    if (since == null || since.isBlank()) {
      return 0L;
    }
    String head = since.split("\\|", 2)[0].trim();
    try {
      return Long.parseLong(head);
    } catch (NumberFormatException ex) {
      return 0L;
    }
  }

  private int normalizeLimit(Integer limit) {
    if (limit == null || limit <= 0) {
      return DEFAULT_LIMIT;
    }
    return Math.min(limit, MAX_LIMIT);
  }

  private String cursor(ProcessedOperationEntity row) {
    return row.getSyncSequence() + "|" + DateTimeFormatter.ISO_INSTANT.format(row.getCreatedAt());
  }

  private String normalizeCursor(String since) {
    return (since == null || since.isBlank()) ? INITIAL_CURSOR : since;
  }

  @SuppressWarnings("unchecked")
  private Map<String, Object> readPayload(String json) {
    if (json == null || json.isBlank()) {
      return Map.of();
    }
    try {
      return mapper.readValue(json, Map.class);
    } catch (Exception ex) {
      return Map.of();
    }
  }
}
