/// Estado local de una operacion en el outbox.
///
/// Ciclo de vida definido en `docs/synchronization/sync-contract.md`
/// (§Estados del outbox). `processing` es transitorio y se reinicia a `pending`
/// al arrancar el engine (seguro por la idempotencia del servidor).
enum SyncOutboxStatus {
  pending('PENDING'),
  processing('PROCESSING'),
  completed('COMPLETED'),
  failed('FAILED'),
  quarantined('QUARANTINED');

  const SyncOutboxStatus(this.value);

  /// Valor persistido en la columna `sync_outbox.status`.
  final String value;

  static SyncOutboxStatus fromValue(String value) => values.firstWhere(
    (status) => status.value == value,
    orElse: () => pending,
  );
}

/// Estado visible del agregado en la UI. Es una proyeccion del outbox + sesion
/// (no un estado extra persistido por el contrato).
enum SyncAggregateState {
  localOnly('LOCAL_ONLY'),
  pendingSync('PENDING_SYNC'),
  syncing('SYNCING'),
  synced('SYNCED'),
  failed('FAILED'),
  quarantined('QUARANTINED');

  const SyncAggregateState(this.value);

  /// Valor persistido en la columna `sync_state` de las tablas locales.
  final String value;

  static SyncAggregateState fromValue(String value) => values.firstWhere(
    (state) => state.value == value,
    orElse: () => localOnly,
  );
}
