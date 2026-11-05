/// Utilidad para calcular edad de forma consistente.
/// Calcula años, meses y días de manera exacta teniendo en cuenta el calendario.
class AgeCalculator {
  /// Calcula la edad completa a partir de una fecha de nacimiento.
  ///
  /// Retorna un mapa con:
  /// - `years`: años completos
  /// - `months`: meses restantes (0-11)
  /// - `days`: días restantes del mes (0-31)
  /// - `totalMonths`: total acumulado de meses desde el nacimiento
  /// - `totalDays`: total acumulado de días desde el nacimiento
  static Map<String, int> calculate(DateTime birthDate) {
    final now = DateTime.now();

    if (birthDate.isAfter(now)) {
      return {
        'years': 0,
        'months': 0,
        'days': 0,
        'totalMonths': 0,
        'totalDays': 0,
      };
    }

    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;
    int days = now.day - birthDate.day;

    if (days < 0) {
      months--;
      final previousMonth = DateTime(now.year, now.month, 0);
      days += previousMonth.day;
    }

    if (months < 0) {
      years--;
      months += 12;
    }

    final totalMonths =
        (now.year - birthDate.year) * 12 + (now.month - birthDate.month);
    final totalDays = now.difference(birthDate).inDays;

    return {
      'years': years,
      'months': months,
      'days': days,
      'totalMonths': totalMonths.abs(),
      'totalDays': totalDays,
    };
  }

  static String format(Map<String, int> age) {
    return '${age['years']} años, ${age['months']} meses, ${age['days']} días';
  }

  static String formatCompact(Map<String, int> age) {
    return '${age['years']} años, ${age['months']} meses';
  }

  static int getTotalMonths(DateTime birthDate) {
    final now = DateTime.now();
    final totalMonths =
        (now.year - birthDate.year) * 12 + (now.month - birthDate.month);
    return totalMonths.abs();
  }

  static int getTotalDays(DateTime birthDate) {
    return DateTime.now().difference(birthDate).inDays;
  }
}
