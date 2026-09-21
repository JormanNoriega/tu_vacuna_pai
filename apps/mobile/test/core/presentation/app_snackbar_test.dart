import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/presentation/widgets/app_snackbar.dart';

void main() {
  late BuildContext ctx;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
  }

  Future<void> settleIn(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  /// Deja vencer el temporizador para no dejar timers pendientes al cerrar.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(AppSnackbar.duration);
    await tester.pumpAndSettle();
  }

  tearDown(AppSnackbar.dismiss);

  testWidgets('muestra el mensaje arriba y se oculta a los 3s', (tester) async {
    await pumpApp(tester);
    AppSnackbar.success(ctx, 'Paciente listo.');
    await settleIn(tester);

    expect(find.text('Paciente listo.'), findsOneWidget);
    // Aparece en la parte superior de la pantalla.
    expect(tester.getTopLeft(find.text('Paciente listo.')).dy, lessThan(120));

    // Se oculta solo al vencer la duracion.
    await drain(tester);
    expect(find.text('Paciente listo.'), findsNothing);
  });

  testWidgets('una sola instancia: el aviso nuevo reemplaza al anterior', (
    tester,
  ) async {
    await pumpApp(tester);
    AppSnackbar.info(ctx, 'Primero');
    await tester.pump();
    AppSnackbar.success(ctx, 'Segundo');
    await settleIn(tester);

    expect(find.text('Primero'), findsNothing);
    expect(find.text('Segundo'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('usa el icono del tipo de aviso', (tester) async {
    await pumpApp(tester);

    AppSnackbar.error(ctx, 'Fallo');
    await settleIn(tester);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);

    AppSnackbar.success(ctx, 'Listo');
    await settleIn(tester);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await drain(tester);
  });

  testWidgets('el boton de accion ejecuta y cierra el aviso', (tester) async {
    await pumpApp(tester);
    var tapped = false;
    AppSnackbar.show(
      ctx,
      'Con accion',
      type: AppSnackbarType.warning,
      actionLabel: 'Reintentar',
      onAction: () => tapped = true,
    );
    await settleIn(tester);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(find.text('Con accion'), findsNothing);
  });
}
