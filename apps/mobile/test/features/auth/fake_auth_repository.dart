import 'package:tu_vacuna_pai/features/auth/domain/entities/auth_user.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/auth/domain/repositories/auth_repository.dart';

/// Repositorio de autenticacion en memoria para pruebas del [AuthController].
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({SessionRestoreResult? restoreResult, this.signInError})
    : restoreResult = restoreResult ?? SessionRestoreResult.signedOut();

  SessionRestoreResult restoreResult;
  Object? signInError;
  int restoreCalls = 0;
  int signOutCalls = 0;
  AuthUser? lastSignInUser;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final error = signInError;
    if (error != null) throw error;
    final user = lastSignInUser ?? demoUser;
    lastSignInUser = user;
    return user;
  }

  @override
  Future<SessionRestoreResult> restoreSession() async {
    restoreCalls++;
    return restoreResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

AuthUser get demoUser => AuthUser(
  id: 'user-1',
  email: 'vacunador@hosp-a.com',
  name: 'Ana Vacunadora',
  institution: const InstitutionProfile(
    id: 'inst-1',
    code: 'HOSP-A',
    name: 'Hospital A',
  ),
  roles: const ['VACCINATOR'],
  permissions: const ['PATIENT_READ', 'ATTENTION_CREATE'],
  offlineWindowHours: 72,
  lastOnlineValidation: DateTime.now().subtract(const Duration(hours: 20)),
);
