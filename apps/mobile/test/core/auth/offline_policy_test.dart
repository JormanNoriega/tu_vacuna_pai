import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_policy.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';

void main() {
  const policy = OfflinePolicy();
  const operation = OperationPermission.createVaccinator;

  group('OfflinePolicy', () {
    test('permite online con el permiso requerido', () {
      expect(
        () => policy.ensureWritable(
          status: SessionStatus.signedIn,
          permissions: const ['USER_MANAGE'],
          operation: operation,
        ),
        returnsNormally,
      );
    });

    test('rechaza online sin el permiso requerido', () {
      expect(
        () => policy.ensureWritable(
          status: SessionStatus.signedIn,
          permissions: const ['PATIENT_READ'],
          operation: operation,
        ),
        throwsA(isA<OfflinePermissionDeniedException>()),
      );
    });

    test('permite offline autorizado solo si la operacion lo esta', () {
      expect(
        () => policy.ensureWritable(
          status: SessionStatus.offlineAuthorized,
          permissions: const ['USER_MANAGE'],
          operation: operation,
        ),
        throwsA(isA<OfflineOperationNotAuthorizedException>()),
      );
    });

    test('bloquea toda escritura en offlineLocked', () {
      expect(
        () => policy.ensureWritable(
          status: SessionStatus.offlineLocked,
          permissions: const ['USER_MANAGE'],
          operation: operation,
        ),
        throwsA(isA<OfflineLockedException>()),
      );
    });

    test('bloquea en signedOut como defensa', () {
      expect(
        () => policy.ensureWritable(
          status: SessionStatus.signedOut,
          permissions: const ['USER_MANAGE'],
          operation: operation,
        ),
        throwsA(isA<OfflineLockedException>()),
      );
    });
  });
}
