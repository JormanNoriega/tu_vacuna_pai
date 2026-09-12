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

import '../../features/admin/fake_admin_repository.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxRepository outbox;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    outbox = SyncOutboxRepository(db);
    await db.upsertCurrentUser(
      id: 'user-1',
      email: 'vac@test.co',
      fullName: 'Vacunador',
      institutionId: 'inst-1',
      roles: const ['VACCINATOR'],
      permissions: const ['ATTENTION_CREATE', 'PATIENT_WRITE'],
      offlineWindowHours: 24,
      lastOnlineValidation: 0,
    );
  });

  tearDown(() => db.close());

  SyncEngine engineWith(MockClient client) => SyncEngine(
    apiClient: ApiClient(baseUrl: 'http://api.test', httpClient: client),
    outbox: outbox,
    database: db,
    sessionManager: FakeSessionManager('token-123'),
  );

  const patientOperation = SyncOperation(
    operationId: 'op-push-1',
    commandType: SyncCommandType.createPatient,
    aggregateId: 'pat-push-1',
    payload: {
      'documentType': 'CC',
      'documentNumber': '111',
      'firstName': 'Ana',
      'lastName': 'Diaz',
      'birthDate': '2019-01-01',
      'sex': 'FEMALE',
    },
  );

  test('marca completed y synced al recibir accepted', () async {
    await db.upsertPatientLocal(
      PatientsLocalCompanion.insert(
        id: 'pat-push-1',
        institutionId: 'inst-1',
        documentType: 'CC',
        documentNumber: '111',
        firstName: 'Ana',
        lastName: 'Diaz',
        syncState: SyncAggregateState.pendingSync.value,
        version: 0,
        updatedAt: 0,
      ),
    );
    await outbox.enqueue(patientOperation);

    final engine = engineWith(
      MockClient((request) async {
        if (request.url.path.endsWith('/sync/push')) {
          return http.Response(
            jsonEncode({
              'accepted': ['op-push-1'],
              'rejected': <dynamic>[],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'operations': []}), 200);
      }),
    );

    final outcome = await engine.syncOnce();

    expect(outcome.pushed, 1);
    expect(
      (await outbox.byOperationId('op-push-1'))!.status,
      SyncOutboxStatus.completed,
    );
    expect(
      (await db.patientLocalById('pat-push-1'))!.syncState,
      SyncAggregateState.synced.value,
    );
    expect(await outbox.pendingCount(), 0);
  });

  test('no reenvia operaciones ya completadas (idempotencia)', () async {
    await outbox.enqueue(patientOperation);
    var pushCalls = 0;
    final engine = engineWith(
      MockClient((request) async {
        if (request.url.path.endsWith('/sync/push')) {
          pushCalls++;
          return http.Response(
            jsonEncode({
              'accepted': ['op-push-1'],
              'rejected': <dynamic>[],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'operations': []}), 200);
      }),
    );

    await engine.syncOnce();
    final second = await engine.syncOnce();

    expect(pushCalls, 1);
    expect(second.pushed, 0);
  });

  test('applica el pull al working set y deduplica por operationId', () async {
    var pullCalls = 0;
    final engine = engineWith(
      MockClient((request) async {
        if (request.url.path.endsWith('/sync/pull')) {
          pullCalls++;
          return http.Response(
            jsonEncode({
              'operations': [
                {
                  'operationId': 'op-pull-1',
                  'commandType': 'CREATE_PATIENT',
                  'aggregateId': 'pat-pull-1',
                  'payload': {
                    'documentType': 'RC',
                    'documentNumber': '222',
                    'firstName': 'Luis',
                    'lastName': 'Rojas',
                    'birthDate': '2021-03-04',
                    'sex': 'MALE',
                    'contacts': [
                      {'type': 'PHONE', 'value': '3009998877'},
                    ],
                  },
                },
              ],
              'nextCursor': '1|2026-01-01T00:00:00Z',
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'accepted': [], 'rejected': []}), 200);
      }),
    );

    final first = await engine.syncOnce();
    final second = await engine.syncOnce();

    expect(first.pulled, 1);
    expect(second.pulled, 0);
    expect(pullCalls, 2);

    final patient = await db.patientLocalById('pat-pull-1');
    expect(patient!.firstName, 'Luis');
    expect(patient.phone, '3009998877');
    expect(await db.syncMetadataValue('last_pull_cursor'), isNotNull);
  });

  test('cuarentena cuando el usuario fue desactivado', () async {
    await db.upsertPatientLocal(
      PatientsLocalCompanion.insert(
        id: 'pat-push-1',
        institutionId: 'inst-1',
        documentType: 'CC',
        documentNumber: '111',
        firstName: 'Ana',
        lastName: 'Diaz',
        syncState: SyncAggregateState.pendingSync.value,
        version: 0,
        updatedAt: 0,
      ),
    );
    await outbox.enqueue(patientOperation);

    final engine = engineWith(
      MockClient((request) async {
        if (request.url.path.endsWith('/sync/push')) {
          return http.Response(
            jsonEncode({
              'accepted': <dynamic>[],
              'rejected': [
                {'operationId': 'op-push-1', 'reason': 'USER_NOT_ACTIVE'},
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'operations': []}), 200);
      }),
    );

    await engine.syncOnce();

    expect(
      (await outbox.byOperationId('op-push-1'))!.status,
      SyncOutboxStatus.quarantined,
    );
    expect(
      (await db.patientLocalById('pat-push-1'))!.syncState,
      SyncAggregateState.quarantined.value,
    );
  });

  test('reencola cuando falta una dependencia', () async {
    await outbox.enqueue(patientOperation);
    final engine = engineWith(
      MockClient((request) async {
        if (request.url.path.endsWith('/sync/push')) {
          return http.Response(
            jsonEncode({
              'accepted': <dynamic>[],
              'rejected': [
                {'operationId': 'op-push-1', 'reason': 'DEPENDENCY_NOT_FOUND'},
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'operations': []}), 200);
      }),
    );

    await engine.syncOnce();

    expect(
      (await outbox.byOperationId('op-push-1'))!.status,
      SyncOutboxStatus.pending,
    );
  });
}
