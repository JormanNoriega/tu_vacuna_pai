import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/core/storage/app_database.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_engine.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_operation.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_outbox.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_status.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_status_controller.dart';

import '../../features/admin/fake_admin_repository.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxRepository outbox;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    outbox = SyncOutboxRepository(db);
  });
  tearDown(() => db.close());

  Future<void> enqueue() => outbox.enqueue(
    const SyncOperation(
      operationId: 'op-1',
      commandType: SyncCommandType.createPatient,
      aggregateId: 'patient-1',
      payload: {},
    ),
  );

  SyncEngine engine(MockClient client) => SyncEngine(
    apiClient: ApiClient(baseUrl: 'http://api.test', httpClient: client),
    outbox: outbox,
    database: db,
    sessionManager: FakeSessionManager('token'),
  );

  test(
    'observa los envíos automáticos y refleja las confirmaciones del servidor',
    () async {
      await enqueue();
      final push = Completer<http.Response>();
      final sync = engine(
        MockClient((request) async {
          if (request.url.path.endsWith('/sync/push')) return push.future;
          return http.Response(jsonEncode({'operations': []}), 200);
        }),
      );
      final controller = SyncStatusController(outbox: outbox, engine: sync);
      await controller.refresh();
      final idle = Completer<void>();
      final processing = Completer<void>();
      controller.addListener(() {
        if (controller.entries.any(
              (entry) => entry.status == SyncOutboxStatus.processing,
            ) &&
            !processing.isCompleted) {
          processing.complete();
        }
        if (!controller.syncing &&
            controller.lastOutcome != null &&
            !idle.isCompleted) {
          idle.complete();
        }
      });
      final cycle = sync
          .syncOnce(); // El scheduler llama al engine directamente.
      expect(controller.syncing, isTrue);
      expect(controller.pendingCount, 1);
      await processing.future;

      push.complete(
        http.Response(
          jsonEncode({
            'accepted': ['op-1'],
            'rejected': [],
          }),
          200,
        ),
      );
      await cycle;
      await idle.future;
      expect(controller.syncing, isFalse);
      expect(controller.pendingCount, 0);
      expect(controller.lastOutcome!.pushed, 1);
      controller.dispose();
      sync.dispose();
    },
  );

  test(
    'los rechazos siguen visibles y no aparentan estar sincronizados',
    () async {
      await enqueue();
      final sync = engine(
        MockClient((request) async {
          if (request.url.path.endsWith('/sync/push')) {
            return http.Response(
              jsonEncode({
                'accepted': [],
                'rejected': [
                  {'operationId': 'op-1', 'reason': 'PERMISSION_DENIED'},
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'operations': []}), 200);
        }),
      );
      final controller = SyncStatusController(outbox: outbox, engine: sync);
      await controller.syncNow();
      expect(controller.hasPending, isTrue);
      expect(controller.pendingCount, 1);
      expect(controller.entries.single.status, SyncOutboxStatus.quarantined);
      controller.dispose();
      sync.dispose();
    },
  );

  test(
    'un fallo de transporte conserva los pendientes aunque el pull funcione',
    () async {
      await enqueue();
      final sync = engine(
        MockClient((request) async {
          if (request.url.path.endsWith('/sync/push')) {
            return http.Response('Servidor no disponible', 503);
          }
          return http.Response(jsonEncode({'operations': []}), 200);
        }),
      );
      final controller = SyncStatusController(outbox: outbox, engine: sync);
      await controller.syncNow();
      expect(controller.pendingCount, 1);
      expect(controller.entries.single.status, SyncOutboxStatus.pending);
      expect(controller.syncing, isFalse);
      controller.dispose();
      sync.dispose();
    },
  );
}
