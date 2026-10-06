import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/presentation/widgets/loading_button.dart';

void main() {
  testWidgets('muestra el icono y ejecuta la accion cuando no carga', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadingButton(
            onPressed: () => taps++,
            loading: false,
            icon: Icons.vaccines_rounded,
            label: 'Registrar dosis',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.vaccines_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Registrar dosis'));
    expect(taps, 1);
  });

  testWidgets('muestra spinner, oculta el icono y no permite pulsar', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadingButton(
            onPressed: () => taps++,
            loading: true,
            icon: Icons.vaccines_rounded,
            label: 'Registrar dosis',
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.vaccines_rounded), findsNothing);

    await tester.tap(find.text('Registrar dosis'));
    expect(taps, 0);
  });

  testWidgets('el estilo outlined usa OutlinedButton con spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadingButton(
            onPressed: () {},
            loading: true,
            style: LoadingButtonStyle.outlined,
            icon: Icons.cancel_outlined,
            label: 'Anular atención',
          ),
        ),
      ),
    );

    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('muestra loadingLabel mientras carga', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadingButton(
            onPressed: () {},
            loading: true,
            loadingLabel: 'Registrando dosis...',
            label: 'Registrar dosis',
          ),
        ),
      ),
    );

    expect(find.text('Registrando dosis...'), findsOneWidget);
    expect(find.text('Registrar dosis'), findsNothing);
  });

  testWidgets('sin loadingLabel mantiene el label durante la carga', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadingButton(
            onPressed: () {},
            loading: true,
            label: 'Registrar dosis',
          ),
        ),
      ),
    );

    expect(find.text('Registrar dosis'), findsOneWidget);
  });
}
