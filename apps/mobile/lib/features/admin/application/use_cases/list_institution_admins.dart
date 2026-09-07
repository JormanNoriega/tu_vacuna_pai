import '../../domain/entities/institution_admin.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/use_cases/list_institutions.dart';

/// Obtiene los administradores de cada institucion agregando los resultados.
///
/// Caso de uso de orquestacion (capa de aplicacion): coordina el listado de
/// instituciones y agrega los administradores de cada una en paralelo. No
/// contiene reglas de negocio de dominio.
class ListInstitutionAdmins {
  ListInstitutionAdmins({
    required AdminRepository repository,
    required ListInstitutions listInstitutions,
  }) : this._(repository, listInstitutions);

  ListInstitutionAdmins._(this._repository, this._listInstitutions);

  final AdminRepository _repository;
  final ListInstitutions _listInstitutions;

  Future<List<InstitutionAdmin>> call(String token) async {
    final institutions = await _listInstitutions(token);
    final results = await Future.wait(
      institutions.map(
        (institution) => _repository.listUsersByInstitution(
          token,
          institutionId: institution.id,
        ),
      ),
    );
    return results.expand((admins) => admins).toList();
  }
}
