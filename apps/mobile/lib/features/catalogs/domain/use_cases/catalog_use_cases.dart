import '../entities/catalog_entities.dart';
import '../repositories/catalog_repository.dart';

class ListVaccines {
  const ListVaccines(this.repository);
  final CatalogRepository repository;
  Future<List<Vaccine>> call(String token) => repository.listVaccines(token);
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
