import '../entities/catalog_entities.dart';
import '../entities/effective_catalog.dart';
import '../entities/geo.dart';
import '../repositories/catalog_repository.dart';

class ListVaccines {
  const ListVaccines(this.repository);
  final CatalogRepository repository;
  Future<List<Vaccine>> call(String token) => repository.listVaccines(token);
}

class ListEffectiveCatalog {
  const ListEffectiveCatalog(this.repository);
  final CatalogRepository repository;
  Future<List<EffectiveVaccine>> call(String token) =>
      repository.listEffectiveCatalog(token);
}

class ListDepartments {
  const ListDepartments(this.repository);
  final CatalogRepository repository;
  Future<List<GeoDepartment>> call(String token) =>
      repository.listDepartments(token);
}

class ListMunicipalities {
  const ListMunicipalities(this.repository);
  final CatalogRepository repository;
  Future<List<GeoMunicipality>> call(String token, String departmentId) =>
      repository.listMunicipalities(token, departmentId);
}

class ListAvailableInstitutionVaccines {
  const ListAvailableInstitutionVaccines(this.repository);
  final CatalogRepository repository;
  Future<List<Vaccine>> call(String token, String institutionId) =>
      repository.listAvailableInstitutionVaccines(token, institutionId);
}

class SaveVaccine {
  const SaveVaccine(this.repository);
  final CatalogRepository repository;
  Future<Vaccine> call(
    String token,
    Map<String, dynamic> body, {
    Vaccine? existing,
  }) => existing == null
      ? repository.createVaccine(token, body)
      : repository.updateVaccine(token, existing, body);
}

class ToggleInstitutionVaccine {
  const ToggleInstitutionVaccine(this.repository);
  final CatalogRepository repository;
  Future<void> call(
    String token,
    Vaccine vaccine,
    String institutionId,
    bool enabled,
  ) => repository.setEnabled(
    token,
    vaccine,
    institutionId: institutionId,
    enabled: enabled,
  );
}
