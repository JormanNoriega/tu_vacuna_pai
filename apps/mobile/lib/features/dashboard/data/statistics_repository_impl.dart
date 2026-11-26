import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/storage/app_database.dart';
import '../domain/entities/statistics_dashboard.dart';
import '../domain/repositories/statistics_repository.dart';

class StatisticsRepositoryImpl implements StatisticsRepository {
  StatisticsRepositoryImpl({required this.api, required this.database});

  final ApiClient api;
  final AppDatabase database;

  static const _cacheKey = 'statistics_dashboard';

  @override
  Future<StatisticsDashboard> remote(
    String accessToken, {
    required DateTime from,
    required DateTime to,
    required String granularity,
  }) async {
    final json = await api.fetchStatisticsDashboard(
      accessToken,
      from: from,
      to: to,
      granularity: granularity,
    );
    await database.setSyncMetadata(_cacheKey, jsonEncode(json));
    return StatisticsDashboard.fromJson(json);
  }

  @override
  Future<StatisticsDashboard?> local() async {
    final raw = await database.syncMetadataValue(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    final dashboard = StatisticsDashboard.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    if (!dashboard.hasData) return null;

    final cachedJson = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final status = Map<String, dynamic>.from(cachedJson['status'] as Map? ?? const {});
    status['source'] = 'cache';
    cachedJson['status'] = status;
    return StatisticsDashboard.fromJson(cachedJson);
  }
}
