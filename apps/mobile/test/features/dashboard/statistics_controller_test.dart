import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/features/dashboard/domain/entities/statistics_dashboard.dart';
import 'package:tu_vacuna_pai/features/dashboard/domain/repositories/statistics_repository.dart';
import 'package:tu_vacuna_pai/features/dashboard/presentation/statistics_controller.dart';

import '../admin/fake_admin_repository.dart';

void main() {
  final from = DateTime.utc(2025, 3, 1);
  final to = DateTime.utc(2025, 4, 1);

  late _FakeStatisticsRepository repository;
  late StatisticsController controller;

  setUp(() {
    repository = _FakeStatisticsRepository();
    controller = StatisticsController(
      sessionManager: FakeSessionManager('token-123'),
      repository: repository,
    );
  });

  tearDown(() => controller.dispose());

  test('loads cached data offline and notifies its observers', () async {
    repository.cachedDashboard = dashboard(source: 'cache');
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.load(
      from: from,
      to: to,
      granularity: 'day',
      offline: true,
    );

    expect(controller.dashboard.source, 'cache');
    expect(controller.dashboard.dosesApplied, 4);
    expect(repository.remoteCalls, 0);
    expect(notifications, 1);
  });

  test('notifies observers when remote loading starts and completes', () async {
    repository.remoteDashboard = dashboard(source: 'server');
    final loadingStates = <bool>[];
    controller.addListener(() => loadingStates.add(controller.isLoading));

    await controller.load(
      from: from,
      to: to,
      granularity: 'week',
      offline: false,
    );

    expect(controller.dashboard.source, 'server');
    expect(repository.remoteCalls, 1);
    expect(loadingStates, [true, false]);
    expect(controller.isLoading, isFalse);
  });

  test('preserves cached data and reports an error if the remote request fails', () async {
    repository.cachedDashboard = dashboard(source: 'cache');
    repository.remoteFailure = StateError('backend no disponible');

    await controller.load(
      from: from,
      to: to,
      granularity: 'month',
      offline: false,
    );

    expect(controller.dashboard.source, 'cache');
    expect(controller.dashboard.dosesApplied, 4);
    expect(controller.error, isNotNull);
    expect(controller.isLoading, isFalse);
  });

  test('rejects an empty range without reading the repository', () async {
    await controller.load(
      from: from,
      to: from,
      granularity: 'day',
      offline: false,
    );

    expect(controller.error, contains('periodo seleccionado'));
    expect(repository.localCalls, 0);
    expect(repository.remoteCalls, 0);
  });
}

StatisticsDashboard dashboard({required String source}) => StatisticsDashboard(
  from: DateTime.utc(2025, 3, 1),
  to: DateTime.utc(2025, 4, 1),
  granularity: 'day',
  dosesApplied: 4,
  uniquePatients: 2,
  activeVaccinators: 1,
  dosesPerPatient: 2,
  doseSeries: const [],
  vaccineDistribution: const [],
  vaccinatorProductivity: const [],
  generatedAt: DateTime.utc(2025, 3, 15),
  source: source,
);

class _FakeStatisticsRepository implements StatisticsRepository {
  StatisticsDashboard? cachedDashboard;
  StatisticsDashboard? remoteDashboard;
  Object? remoteFailure;
  int localCalls = 0;
  int remoteCalls = 0;

  @override
  Future<StatisticsDashboard?> local() async {
    localCalls++;
    return cachedDashboard;
  }

  @override
  Future<StatisticsDashboard> remote(
    String accessToken, {
    required DateTime from,
    required DateTime to,
    required String granularity,
  }) async {
    remoteCalls++;
    final failure = remoteFailure;
    if (failure != null) throw failure;
    return remoteDashboard!;
  }
}