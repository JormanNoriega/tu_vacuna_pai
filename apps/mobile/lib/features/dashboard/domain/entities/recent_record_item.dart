class RecentRecordItem {
  const RecentRecordItem({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.vaccineName,
    required this.timestamp,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String vaccineName;
  final DateTime timestamp;

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.isNegative || difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays}d';
    } else {
      final day = timestamp.day.toString().padLeft(2, '0');
      final month = timestamp.month.toString().padLeft(2, '0');
      return '$day/$month/${timestamp.year}';
    }
  }

  factory RecentRecordItem.fromJson(Map<String, dynamic> json) {
    final rawVaccine = json['vaccineName']?.toString();
    final isUuid =
        rawVaccine != null &&
        RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(rawVaccine.trim());
    final displayVaccine =
        (!isUuid && rawVaccine != null && rawVaccine.trim().isNotEmpty)
        ? rawVaccine.trim()
        : 'Atención de vacunación';

    return RecentRecordItem(
      id: json['id']?.toString() ?? '',
      patientId: json['patientId']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? 'Paciente',
      vaccineName: displayVaccine,
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'vaccineName': vaccineName,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
