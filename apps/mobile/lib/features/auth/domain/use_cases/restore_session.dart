import '../entities/session_restore_result.dart';
import '../repositories/auth_repository.dart';

class RestoreSession {
  const RestoreSession(this._repository);

  final AuthRepository _repository;

  Future<SessionRestoreResult> call() => _repository.restoreSession();
}