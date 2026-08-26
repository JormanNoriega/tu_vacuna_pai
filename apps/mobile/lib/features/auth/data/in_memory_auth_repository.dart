import '../domain/entities/auth_exception.dart';
import '../domain/entities/auth_user.dart';
import '../domain/entities/session_restore_result.dart';
import '../domain/repositories/auth_repository.dart';

/// Adaptador temporal usado en tests y como respaldo hasta que haya un
/// usuario real de Supabase con perfil en Spring.
class InMemoryAuthRepository implements AuthRepository {
  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (email.trim().toLowerCase() != 'demo@tuvacunapai.com' ||
        password != 'demo123') {
      throw const AuthException('Correo o contrasena incorrectos.');
    }

    return AuthUser(
      id: '00000000-0000-0000-0000-000000000001',
      email: 'demo@tuvacunapai.com',
      name: 'Personal de vacunacion',
      institution: const InstitutionProfile(
        id: '00000000-0000-0000-0000-000000000010',
        code: 'INST-1',
        name: 'Institucion 1',
      ),
      roles: const ['VACCINATOR'],
      permissions: const [
        'PATIENT_READ',
        'PATIENT_WRITE',
        'ATTENTION_CREATE',
        'ATTENTION_READ',
        'CATALOG_READ',
      ],
      offlineWindowHours: 72,
      lastOnlineValidation: DateTime.now(),
    );
  }

  @override
  Future<SessionRestoreResult> restoreSession() async {
    // Sin persistencia: cada arranque empieza en el login.
    return SessionRestoreResult.signedOut();
  }

  @override
  Future<void> signOut() async {}
}
