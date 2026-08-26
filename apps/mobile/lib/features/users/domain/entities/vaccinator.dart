/// Usuario vacunador (VACCINATOR) de una institucion.
class Vaccinator {
  const Vaccinator({
    required this.id,
    required this.email,
    required this.fullName,
    required this.institutionId,
    required this.roles,
    required this.status,
  });

  factory Vaccinator.fromJson(Map<String, dynamic> json) {
    return Vaccinator(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      institutionId: json['institutionId'] as String,
      roles: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
      status: json['status'] as String,
    );
  }

  final String id;
  final String email;
  final String fullName;
  final String institutionId;
  final List<String> roles;
  final String status;

  bool get isActive => status == 'ACTIVE';
}