import '../../../core/presentation/async_controller.dart';
import '../domain/entities/statistics_dashboard.dart';
import '../domain/repositories/statistics_repository.dart';

class StatisticsController extends AsyncController {
  StatisticsController({
    required super.sessionManager,
    required this.repository,
  });

  final StatisticsRepository repository;

  StatisticsDashboard _dashboard = StatisticsDashboard.empty();
  StatisticsDashboard get dashboard => _dashboard;

  Future<void> load({
    required DateTime from,
    required DateTime to,
    required String granularity,
    required bool offline,
  }) async {
    if (from.isAfter(to) || from.isAtSameMomentAs(to)) {
      setError('El periodo seleccionado no es valido.');
      return;
    }

    final cached = await repository.local();
    if (cached != null) {
      _dashboard = cached;
      notifyListeners();
    }

    if (offline) return;

    await execute((token) async {
      _dashboard = await repository.remote(
        token,
        from: from,
        to: to,
        granularity: granularity,
      );
    });
  }

  void clearSession() {
    _dashboard = StatisticsDashboard.empty();
    clearError();
    notifyListeners();
  }
}
