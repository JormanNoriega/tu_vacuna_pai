import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_admin_web/dashboard/home_view.dart';
import 'package:tu_vacuna_admin_web/dashboard/module_status_view.dart';
import 'package:tu_vacuna_admin_web/dashboard/statistics_view.dart';

void main() {
  testWidgets(
    'inicio usa la estructura administrativa sin métricas inventadas',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: HomeView(
            name: 'Ana',
            institutionName: 'Centro de Salud',
            metrics: Future.value({'patientsAttended': 12, 'dosesApplied': 34}),
            onRefresh: () {},
            onNavigate: selected.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bienvenido, Ana'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('34'), findsOneWidget);
      expect(find.text('Mapa institucional no disponible'), findsOneWidget);
      expect(find.textContaining('Brigada 1'), findsNothing);
      await tester.tap(find.text('Historial'));
      expect(selected, ['historial']);
    },
  );

  testWidgets('inicio y estadísticas se adaptan a una ventana estrecha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeView(
          name: 'Ana',
          institutionName: 'Centro de Salud',
          metrics: Future.value({'patientsAttended': 12, 'dosesApplied': 34}),
          onRefresh: () {},
          onNavigate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsView(
          institutionName: 'Centro de Salud',
          metrics: Future.value({'patientsAttended': 12, 'dosesApplied': 34}),
          onRefresh: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tendencias de vacunación'), findsOneWidget);
  });

  testWidgets('módulo pendiente informa su estado y ofrece rutas conectadas', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ModuleStatusView(
          title: 'Exportación de reportes PAI',
          subtitle: 'Descarga institucional',
          icon: Icons.download_outlined,
          reason: 'El endpoint aún no está conectado.',
          onSelect: selected.add,
          availableSections: const [('Historial', 'historial', Icons.history)],
        ),
      ),
    );

    expect(find.text('MÓDULO EN MIGRACIÓN'), findsOneWidget);
    expect(find.text('El endpoint aún no está conectado.'), findsOneWidget);
    await tester.tap(find.text('Historial'));
    expect(selected, ['historial']);
  });

  testWidgets('estadísticas separa métricas conectadas de datos ausentes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsView(
          institutionName: 'Centro',
          metrics: Future.value({'patientsAttended': 12, 'dosesApplied': 34}),
          onRefresh: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
    expect(find.text('Cobertura PAI'), findsOneWidget);
    expect(find.text('Tendencias de vacunación'), findsOneWidget);
    expect(
      find.text(
        'No se muestran rankings ni comparaciones: el resumen disponible no incluye actividad por profesional.',
      ),
      findsOneWidget,
    );
  });
}
