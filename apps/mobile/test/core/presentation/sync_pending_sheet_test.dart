import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/presentation/widgets/app_snackbar.dart';
import 'package:tu_vacuna_pai/core/presentation/widgets/sync_pending_sheet.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_engine.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_operation.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_status.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_status_controller.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/auth_user.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/dashboard/presentation/pages/dashboard_page.dart';

OutboxEntry _entry(
  String id, [
  SyncOutboxStatus status = SyncOutboxStatus.pending,
]) => OutboxEntry(
  operation: SyncOperation(
    operationId: id,
    commandType: SyncCommandType.createPatient,
    aggregateId: 'patient-$id',
    payload: const {},
    summary: 'Paciente $id',
  ),
  status: status,
  retryCount: 0,
);

class _SyncController extends ChangeNotifier implements SyncStatusController {
  _SyncController(this.entries);

  @override
  List<OutboxEntry> entries;
  @override
  bool syncing = false;
  @override
  SyncOutcome? lastOutcome;
  Completer<SyncOutcome>? _cycle;

  @override
  int get pendingCount => entries.length;
  @override
  bool get hasPending => entries.isNotEmpty;
  @override
  Future<void> refresh() async => notifyListeners();
  @override
  Future<List<OutboxEntry>> pendingEntries() async => entries;

  @override
  Future<SyncOutcome> syncNow() {
    syncing = true;
    lastOutcome = null;
    entries = [
      for (final entry in entries)
        _entry(entry.operation.operationId, SyncOutboxStatus.processing),
    ];
    _cycle = Completer<SyncOutcome>();
    notifyListeners();
    return _cycle!.future;
  }

  void finish(List<OutboxEntry> remaining, SyncOutcome outcome) {
    entries = remaining;
    syncing = false;
    lastOutcome = outcome;
    notifyListeners();
    _cycle!.complete(outcome);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(WidgetTester tester, _SyncController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSyncPendingSheet(context, controller),
            child: const Text('Abrir pendientes'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir pendientes'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(AppSnackbar.dismiss);

  testWidgets(
    'cerrar el panel durante el envío no cancela ni cierra otra pantalla',
    (tester) async {
      final controller = _SyncController([_entry('1')]);
      addTearDown(controller.dispose);
      await _open(tester, controller);
      await tester.tap(find.text('Sincronizar ahora'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Continuar en segundo plano'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(controller.syncing, isTrue);
      controller.finish([], const SyncOutcome(pushed: 1));
      await tester.pumpAndSettle();
      expect(find.text('Abrir pendientes'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'un cambio nuevo durante la confirmación evita un cierre con falso éxito',
    (tester) async {
      final controller = _SyncController([_entry('1')]);
      addTearDown(controller.dispose);
      await _open(tester, controller);
      await tester.tap(find.text('Sincronizar ahora'));
      await tester.pump();
      controller.finish([], const SyncOutcome(pushed: 1));
      await tester.pump();
      controller.entries = [_entry('2')];
      await controller.refresh();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Paciente 2'), findsOneWidget);
      expect(
        find.text(
          'Todos los cambios pendientes se sincronizaron correctamente.',
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'anima el envío, confirma, cierra y avisa en la pantalla principal',
    (tester) async {
      final controller = _SyncController([_entry('1')]);
      addTearDown(controller.dispose);
      await _open(tester, controller);
      await tester.tap(find.text('Sincronizar ahora'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('sync-progress')), findsOneWidget);
      expect(find.text('Sincronizando cambios…'), findsOneWidget);
      expect(find.text('Subiendo'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );

      controller.finish([], const SyncOutcome(pushed: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Todo sincronizado'), findsWidgets);
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.text(
          'Todos los cambios pendientes se sincronizaron correctamente.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'mantiene el panel si el ciclo termina con cambios pendientes o rechazados',
    (tester) async {
      final controller = _SyncController([_entry('1'), _entry('2')]);
      addTearDown(controller.dispose);
      await _open(tester, controller);
      await tester.tap(find.text('Sincronizar ahora'));
      await tester.pump();

      controller.finish([
        _entry('2', SyncOutboxStatus.quarantined),
      ], const SyncOutcome(pushed: 1));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Revisar'), findsOneWidget);
      expect(
        find.textContaining('Queda 1 cambio sin sincronizar.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Todos los cambios pendientes se sincronizaron correctamente.',
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('el fallo de red no cierra el panel ni pierde los cambios', (
    tester,
  ) async {
    final controller = _SyncController([_entry('1')]);
    addTearDown(controller.dispose);
    await _open(tester, controller);
    await tester.tap(find.text('Sincronizar ahora'));
    await tester.pump();
    controller.finish([_entry('1')], const SyncOutcome(error: 'Sin red'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.textContaining('Tus cambios siguen guardados.'),
      findsOneWidget,
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'pocos registros ocupan menos altura y una lista larga no desborda',
    (tester) async {
      final controller = _SyncController([_entry('1')]);
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(tester, controller);
      final smallHeight = tester.getSize(find.byType(BottomSheet)).height;
      expect(smallHeight, lessThan(640 * .8));

      controller.entries = [for (var i = 0; i < 30; i++) _entry('$i')];
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(BottomSheet)).height,
        lessThanOrEqualTo(640 * .8),
      );
      expect(find.text('Sincronizar ahora'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'el acceso se oculta online sin pendientes y reaparece si hay cambios o modo offline',
    (tester) async {
      final controller = _SyncController([]);
      addTearDown(controller.dispose);
      final user = AuthUser(
        id: 'vac-1',
        email: 'vac@test.co',
        name: 'Ana',
        roles: const ['VACCINATOR'],
        permissions: const ['ATTENTION_CREATE'],
        institution: const InstitutionProfile(
          id: 'inst-1',
          code: 'A',
          name: 'Hospital',
        ),
        offlineWindowHours: 72,
        lastOnlineValidation: DateTime.now(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardPage(
            user: user,
            onSignOut: () {},
            syncStatusController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sync-pending-button')), findsNothing);

      controller.entries = [_entry('1')];
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sync-pending-button')), findsOneWidget);

      final cycle = controller.syncNow();
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('sync-pending-button')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      controller.finish([], const SyncOutcome(pushed: 1));
      await cycle;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sync-pending-button')), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardPage(
            user: user,
            onSignOut: () {},
            syncStatusController: controller,
            sessionStatus: SessionStatus.offlineAuthorized,
            offlineReason: OfflineReason.noNetwork,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sync-pending-button')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
