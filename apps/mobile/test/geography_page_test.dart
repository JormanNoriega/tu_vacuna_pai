import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_pai/core/auth/session_manager.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/features/geography/geography_controller.dart';
import 'package:tu_vacuna_pai/features/geography/geography_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cambiar modo no realiza otra consulta', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token'});
    var count = 0;
    final response = Completer<http.Response>();
    final controller = GeographyController(
      api: ApiClient(
        baseUrl: 'https://example.test/api/v1',
        httpClient: MockClient((_) {
          count++;
          return response.future;
        }),
      ),
      sessionManager: SessionManager(const FlutterSecureStorage()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GeographyPage(controller: controller, online: true),
        ),
      ),
    );
    await tester.pump();
    expect(count, 1);
    await tester.tap(find.text('Agrupaciones'));
    await tester.pump();
    await tester.tap(find.text('Calor'));
    await tester.pump();
    expect(count, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(
      http.Response('{"generatedAt":"2026-11-25T00:00:00Z","cells":[]}', 200),
    );
    await tester.pump();
  });
}
