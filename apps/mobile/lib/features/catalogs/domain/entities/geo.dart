/// Pais del catalogo geografico.
class GeoCountry {
  const GeoCountry({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;

  factory GeoCountry.fromJson(Map<String, dynamic> json) => GeoCountry(
    id: json['id'].toString(),
    code: json['code'] as String,
    name: json['name'] as String,
  );
}

/// Departamento del catalogo geografico (DIVIPOLA).
class GeoDepartment {
  const GeoDepartment({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String code;
  final String name;

  factory GeoDepartment.fromJson(Map<String, dynamic> json) => GeoDepartment(
    id: json['id'].toString(),
    code: json['code'] as String,
    name: json['name'] as String,
  );
}

/// Municipio del catalogo geografico (DIVIPOLA).
class GeoMunicipality {
  const GeoMunicipality({
    required this.id,
    required this.code,
    required this.name,
    required this.departmentId,
  });

  final String id;
  final String code;
  final String name;
  final String departmentId;

  factory GeoMunicipality.fromJson(Map<String, dynamic> json) =>
      GeoMunicipality(
        id: json['id'].toString(),
        code: json['code'] as String,
        name: json['name'] as String,
        departmentId: json['departmentId'].toString(),
      );
}
