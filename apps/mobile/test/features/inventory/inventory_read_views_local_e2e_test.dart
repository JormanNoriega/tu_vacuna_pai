import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:tu_vacuna_pai/core/auth/session_manager.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/historical_custody_review_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/inventory_controller.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/pending_follow_ups_page.dart';

class _LocalSession extends SessionManager {
  _LocalSession(this.token) : super(const FlutterSecureStorage());
  String token;

  @override
  Future<SessionData?> loadSession() async => SessionData(
    accessToken: token,
    refreshToken: '',
    expiresAt: DateTime(2099),
    lastOnlineValidation: DateTime.now(),
  );
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
  }
  fail('No apareció $finder');
}

void main() {
  final url = Platform.environment['PAI_READ_E2E_URL'];
  const institution = '11111111-1111-4111-8111-111111111111';
  const assignment = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const receipt = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  const event = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

  testWidgets('vistas administrativas leen API local H2 sin escribir', (
    tester,
  ) async {
    if (!RegExp(r'^http://127\.0\.0\.1:[1-9][0-9]{0,4}/api/v1$')
        .hasMatch(url!)) {
      fail('La prueba solo permite la API efímera en 127.0.0.1.');
    }
    HttpOverrides.global = null;
    final session = _LocalSession('test-admin');
    final client = IOClient(HttpClient());
    final controller = InventoryController(
      sessionManager: session,
      api: ApiClient(baseUrl: url, httpClient: client),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: PendingFollowUpsPage(
          controller: controller,
          institutionId: institution,
          online: true,
          canRead: true,
        ),
      ),
    );
    await _waitFor(
      tester,
      find.text('3 frascos pendientes de recepción en depósito'),
    );
    expect(find.text('2 frascos sin regularizar'), findsOneWidget);
    expect(find.textContaining('no son saldos disponibles'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: HistoricalCustodyReviewPage(
          controller: controller,
          institutionId: institution,
          assignmentId: assignment,
          online: true,
          canRead: true,
        ),
      ),
    );
    await _waitFor(tester, find.text('Referencia: $receipt'));
    expect(find.text('Observación: Faltaron dos'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pump();
    expect(find.text('Referencia: $event'), findsOneWidget);
    expect(find.text('Motivo: Devolución contada'), findsOneWidget);
    expect(find.text('Devolución pendiente de recepción'), findsOneWidget);

    session.token = 'test-vaccinator';
    await tester.pumpWidget(
      MaterialApp(
        home: PendingFollowUpsPage(
          key: const ValueKey('denied'),
          controller: controller,
          institutionId: institution,
          online: true,
          canRead: true,
        ),
      ),
    );
    await _waitFor(
      tester,
      find.text(
        'No tienes permiso para consultar o modificar este inventario.',
      ),
    );
    expect(find.text('No hay pendientes en esta consulta.'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: HistoricalCustodyReviewPage(
          key: const ValueKey('history-denied'),
          controller: controller,
          institutionId: institution,
          assignmentId: assignment,
          online: true,
          canRead: true,
        ),
      ),
    );
    await _waitFor(
      tester,
      find.text(
        'No tienes permiso para consultar o modificar este inventario.',
      ),
    );
    expect(find.text('Referencia: $receipt'), findsNothing);

    session.token = 'test-admin';
    await tester.pumpWidget(
      MaterialApp(
        home: HistoricalCustodyReviewPage(
          key: const ValueKey('missing'),
          controller: controller,
          institutionId: institution,
          assignmentId: '99999999-9999-4999-8999-999999999999',
          online: true,
          canRead: true,
        ),
      ),
    );
    await _waitFor(tester, find.textContaining('Entrega no encontrada'));
    expect(find.text('No hay novedades registradas.'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: HistoricalCustodyReviewPage(
          key: const ValueKey('other-institution'),
          controller: controller,
          institutionId: '99999999-9999-4999-8999-999999999999',
          assignmentId: assignment,
          online: true,
          canRead: true,
        ),
      ),
    );
    await _waitFor(
      tester,
      find.text(
        'No tienes permiso para consultar o modificar este inventario.',
      ),
    );
    expect(find.text('Referencia: $receipt'), findsNothing);
    client.close();
    await tester.pump();
  }, skip: url == null);
}
