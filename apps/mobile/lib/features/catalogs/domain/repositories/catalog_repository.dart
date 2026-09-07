import '../entities/catalog_entities.dart';

abstract interface class CatalogRepository {
  Future<List<Vaccine>> listVaccines(String token);
  Future<List<InstitutionVaccine>> listInstitutionVaccines(
    String token,
    String institutionId,
  );

  /// Vacunas activas del catalogo global que aun no tienen relacion con la
  /// institucion (para que el ADMIN_INSTITUTION las habilite).
  Future<List<Vaccine>> listAvailableInstitutionVaccines(
    String token,
    String institutionId,
  );
  Future<Vaccine> createVaccine(String token, Map<String, dynamic> body);
  Future<Vaccine> updateVaccine(
    String token,
    Vaccine vaccine,
    Map<String, dynamic> body,
  );
  Future<void> deleteVaccine(String token, Vaccine vaccine);
  Future<List<VaccineOption>> listOptions(
    String token,
    Vaccine vaccine, {
    required bool institutionScoped,
    required String institutionId,
  });
  Future<VaccineOption> createOption(
    String token,
    Vaccine vaccine,
    Map<String, dynamic> body, {
    required bool institutionScoped,
    required String institutionId,
  });
  Future<VaccineOption> updateOption(
    String token,
    Vaccine vaccine,
    VaccineOption option,
    Map<String, dynamic> body, {
    required bool institutionScoped,
    required String institutionId,
  });
  Future<void> deleteOption(
    String token,
    Vaccine vaccine,
    VaccineOption option, {
    required bool institutionScoped,
    required String institutionId,
  });

  /// Desactiva una opcion construyendo el payload de transporte (DTO) en la
  /// capa de datos. El controller no conoce el shape del wire protocol.
  Future<void> disableOption(
    String token,
    Vaccine vaccine,
    VaccineOption option, {
    required bool institutionScoped,
    required String institutionId,
  });
  Future<void> setEnabled(
    String token,
    Vaccine vaccine, {
    required String institutionId,
    required bool enabled,
  });
  Future<List<VaccineOption>> suggestedOptions(
    String token,
    Vaccine vaccine,
    String institutionId,
  );
  Future<List<VaccineOption>> listTemplates(String token, Vaccine vaccine);
  Future<VaccineOption> createTemplate(
    String token,
    Vaccine vaccine,
    Map<String, dynamic> body,
  );
  Future<List<VaccineOption>> importSuggestedOptions(
    String token,
    Vaccine vaccine,
    String institutionId,
  );
}
