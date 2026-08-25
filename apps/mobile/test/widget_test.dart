import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/app/app.dart';

void main() {
  testWidgets('muestra login sin registro publico', (tester) async {
    await tester.pumpWidget(const TuVacunaApp());

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Iniciar sesion'), findsOneWidget);
    expect(find.textContaining('No hay registro publico'), findsOneWidget);
  });

  testWidgets('permite iniciar sesion y muestra el dashboard', (tester) async {
    await tester.pumpWidget(const TuVacunaApp());
    await tester.tap(find.text('Iniciar sesion'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Buenos dias'), findsOneWidget);
    expect(find.text('Todo esta sincronizado'), findsOneWidget);
    expect(find.text('Acciones frecuentes'), findsOneWidget);
  });
}
