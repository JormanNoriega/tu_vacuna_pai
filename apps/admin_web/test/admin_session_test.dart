import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_admin_web/connection/admin_api.dart';
import 'package:tu_vacuna_admin_web/connection/admin_session.dart';

class FakeAuth implements AuthGateway {
  int signOuts = 0;
  Duration lifetime = const Duration(hours: 1);
  @override
  Future<SessionToken> signIn(String email, String password) async =>
      SessionToken('token', DateTime.now().add(lifetime));
  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

void main() {
  Map<String, Object> profile(String role) => {
    'id': 'u',
    'fullName': 'Ana',
    'roles': [role],
    'permissions': <String>[],
    'institution': {'id': 'i'},
  };
  AdminSession make(FakeAuth auth, http.Response response) => AdminSession(
    auth,
    AdminApi(
      Uri.parse('https://example.test/api/v1'),
      client: MockClient((_) async => response),
    ),
  );

  test('valida rol en Spring y cierra la sesión', () async {
    final auth = FakeAuth();
    final session = make(
      auth,
      http.Response(jsonEncode(profile('SUPER_ADMIN')), 200),
    );
    addTearDown(session.dispose);
    await session.signIn('a@b.co', 'password');
    expect(session.name, 'Ana');
    await session.signOut();
    expect(session.name, isNull);
    expect(auth.signOuts, 1);
  });

  test('rechaza rol no administrativo y error de Spring', () async {
    for (final response in [
      http.Response(jsonEncode(profile('VACCINATOR')), 200),
      http.Response('{}', 503),
      http.Response('{"roles":["SUPER_ADMIN"],"fullName":"Ana"}', 200),
    ]) {
      final auth = FakeAuth();
      final session = make(auth, response);
      await session.signIn('a@b.co', 'password');
      expect(session.name, isNull);
      expect(session.error, isNotNull);
      expect(auth.signOuts, 1);
      session.dispose();
    }
  });

  test('la expiración elimina el acceso', () async {
    final auth = FakeAuth()..lifetime = const Duration(milliseconds: 50);
    final session = make(
      auth,
      http.Response(jsonEncode(profile('ADMIN_INSTITUTION')), 200),
    );
    addTearDown(session.dispose);
    await session.signIn('a@b.co', 'password');
    expect(session.name, 'Ana');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(session.name, isNull);
    expect(auth.signOuts, 1);
  });
}
