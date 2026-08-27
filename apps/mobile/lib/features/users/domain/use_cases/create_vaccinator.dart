import '../../../../core/auth/offline_access.dart';
import '../../../../core/auth/offline_policy.dart';
import '../entities/vaccinator.dart';
import '../repositories/users_repository.dart';

class CreateVaccinator {
  const CreateVaccinator(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final UsersRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<Vaccinator> call(
    String accessToken, {
    required OfflineAccess offline,
    required String email,
    required String fullName,
    required String temporaryPassword,
    required String operationId,
    required String documentType,
    required String documentNumber,
    String? phone,
    String? birthDate,
    String? gender,
    required String professionCode,
    String? professionalRegistrationNumber,
    String? professionalRegistrationType,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.createVaccinator,
    );
    return _repository.createVaccinator(
      accessToken,
      email: email,
      fullName: fullName,
      temporaryPassword: temporaryPassword,
      operationId: operationId,
      documentType: documentType,
      documentNumber: documentNumber,
      phone: phone,
      birthDate: birthDate,
      gender: gender,
      professionCode: professionCode,
      professionalRegistrationNumber: professionalRegistrationNumber,
      professionalRegistrationType: professionalRegistrationType,
    );
  }
}
