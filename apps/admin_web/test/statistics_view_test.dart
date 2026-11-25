import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_admin_web/dashboard/statistics_view.dart';

void main() {
  testWidgets('muestra datos reales y permite actualizar', (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsView(
          institutionName: 'Centro',
          metrics: Future.value({'patientsAttended': 12, 'dosesApplied': 34}),
          onRefresh: () => refreshes++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
    expect(
      find.textContaining('Los totales disponibles son históricos'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Actualizar indicadores').first);
    expect(refreshes, 1);
  });

  testWidgets('informa errores sin mostrar datos inventados', (tester) async {
    var refreshes = 0;
    final result = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsView(
          institutionName: 'Centro',
          metrics: result.future,
          onRefresh: () => refreshes++,
        ),
      ),
    );
    result.completeError(Exception('sin conexión'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No se pudieron consultar las métricas'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reintentar'));
    expect(refreshes, 1);
  });
}
