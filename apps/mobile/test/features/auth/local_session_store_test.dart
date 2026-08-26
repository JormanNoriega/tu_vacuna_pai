import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/storage/app_database.dart';
import 'package:tu_vacuna_pai/features/auth/data/local_session_store.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/auth_user.dart';

import 'fake_auth_repository.dart';

void main() {
  late AppDatabase database;
  late LocalSessionStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = LocalSessionStore(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('persiste y restaura el perfil autorizado con su institucion', () async {
    await store.saveProfile(demoUser);

    final restored = await store.loadProfile();

    expect(restored, isNotNull);
    expect(restored!.id, demoUser.id);
    expect(restored.email, demoUser.email);
    expect(restored.name, demoUser.name);
    expect(restored.institution.id, demoUser.institution.id);
    expect(restored.institution.code, demoUser.institution.code);
    expect(restored.roles, demoUser.roles);
    expect(restored.permissions, demoUser.permissions);
    expect(restored.offlineWindowHours, demoUser.offlineWindowHours);
    // El store normaliza a segundos UTC; se compara el mismo instante con 1s
    // de tolerancia por el truncado de subsegundos.
    expect(
      restored.lastOnlineValidation
          .difference(demoUser.lastOnlineValidation)
          .inSeconds
          .abs(),
      lessThanOrEqualTo(1),
    );
  });

  test('devuelve null cuando no hay perfil guardado', () async {
    expect(await store.loadProfile(), isNull);
  });

  test('limpia el perfil al cerrar sesion', () async {
    await store.saveProfile(demoUser);
    await store.clearProfile();

    expect(await store.loadProfile(), isNull);
  });

  test('sobrescribe el perfil anterior al validar de nuevo', () async {
    await store.saveProfile(demoUser);

    final updated = AuthUser(
      id: demoUser.id,
      email: demoUser.email,
      name: 'Ana Actualizada',
      institution: demoUser.institution,
      roles: const ['VACCINATOR'],
      permissions: const ['PATIENT_READ'],
      offlineWindowHours: 24,
      lastOnlineValidation: DateTime.utc(2026, 8, 26, 9),
    );
    await store.saveProfile(updated);

    final restored = await store.loadProfile();
    expect(restored!.name, 'Ana Actualizada');
    expect(restored.offlineWindowHours, 24);
    expect(restored.lastOnlineValidation, DateTime.utc(2026, 8, 26, 9));
  });
}
