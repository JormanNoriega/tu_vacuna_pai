/// Usuario administrativo de una institucion (ADMIN_INSTITUTION).
class InstitutionAdmin {
  const InstitutionAdmin({
    required this.id,
    required this.email,
    required this.fullName,
    required this.institutionId,
    required this.roles,
  });

  factory InstitutionAdmin.fromJson(Map<String, dynamic> json) {
    return InstitutionAdmin(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      institutionId: json['institutionId'] as String,
      roles: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  final String id;
  final String email;
  final String fullName;
  final String institutionId;
  final List<String> roles;
}