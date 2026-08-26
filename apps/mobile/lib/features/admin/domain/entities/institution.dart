/// Institucion gestionada por el SUPER_ADMIN.
class Institution {
  const Institution({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.offlineWindowHours,
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      offlineWindowHours: json['offlineWindowHours'] as int,
    );
  }

  final String id;
  final String code;
  final String name;
  final String status;
  final int offlineWindowHours;

  bool get isActive => status == 'ACTIVE';
}
