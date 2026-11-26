import '../entities/statistics_dashboard.dart';

abstract interface class StatisticsRepository {
  Future<StatisticsDashboard> remote(
    String accessToken, {
    required DateTime from,
    required DateTime to,
    required String granularity,
  });

  Future<StatisticsDashboard?> local();
}
