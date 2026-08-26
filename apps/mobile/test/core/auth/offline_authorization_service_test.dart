import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_authorization_service.dart';

void main() {
  const service = OfflineAuthorizationService();
  final now = DateTime.utc(2026, 8, 26, 12, 0, 0);

  group('OfflineAuthorizationService', () {
    test('autoriza dentro de la ventana offline', () {
      final last = now.subtract(const Duration(hours: 20));

      expect(
        service.evaluate(
          lastOnlineValidation: last,
          offlineWindowHours: 72,
          now: now,
        ),
        OfflineAuthorizationState.authorized,
      );
    });

    test('autoriza justo en el limite de la ventana (<=)', () {
      final last = now.subtract(const Duration(hours: 72));

      expect(
        service.evaluate(
          lastOnlineValidation: last,
          offlineWindowHours: 72,
          now: now,
        ),
        OfflineAuthorizationState.authorized,
      );
    });

    test('bloquea cuando la ventana offline vencio', () {
      final last = now.subtract(const Duration(hours: 80));

      expect(
        service.evaluate(
          lastOnlineValidation: last,
          offlineWindowHours: 72,
          now: now,
        ),
        OfflineAuthorizationState.expired,
      );
    });

    test('no depende de la expiracion del token: ventana corta con last recente', () {
      final last = now.subtract(const Duration(hours: 1));

      expect(
        service.evaluate(
          lastOnlineValidation: last,
          offlineWindowHours: 72,
          now: now,
        ),
        OfflineAuthorizationState.authorized,
      );
    });

    test('reporta noProfile sin validacion previa', () {
      expect(
        service.evaluate(
          lastOnlineValidation: null,
          offlineWindowHours: 72,
          now: now,
        ),
        OfflineAuthorizationState.noProfile,
      );
    });
  });
}