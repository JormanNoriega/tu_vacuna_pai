/// Respuesta de `GET /api/v1/me` (Spring). Perfil autorizado del usuario.
class MeResponse {
  const MeResponse({
    required this.id,
    required this.email,
    required this.fullName,
    required this.institution,
    required this.roles,
    required this.permissions,
    required this.offlineWindowHours,
    required this.lastOnlineValidation,
  });

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      institution: InstitutionDto.fromJson(
        json['institution'] as Map<String, dynamic>,
      ),
      roles: (json['roles'] as List<dynamic>).cast<String>(),
      permissions: (json['permissions'] as List<dynamic>).cast<String>(),
      offlineWindowHours: json['offlineWindowHours'] as int,
      lastOnlineValidation: json['lastOnlineValidation'] as String,
    );
  }

  final String id;
  final String email;
  final String fullName;
  final InstitutionDto institution;
  final List<String> roles;
  final List<String> permissions;
  final int offlineWindowHours;
  final String lastOnlineValidation;
}

class InstitutionDto {
  const InstitutionDto({
    required this.id,
    required this.code,
    required this.name,
  });

  factory InstitutionDto.fromJson(Map<String, dynamic> json) {
    return InstitutionDto(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }

  final String id;
  final String code;
  final String name;
}