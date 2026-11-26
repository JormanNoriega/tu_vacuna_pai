import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/features/dashboard/presentation/widgets/admin_web_sidebar.dart';

void main() {
  testWidgets('el sidebar solo cambia de ancho con su botón', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AdminWebSidebar(
                selectedSection: 'inicio',
                onSelectSection: (_) {},
                onAction: (_) {},
                onSignOut: () {},
                userName: 'María',
                institutionName: 'Hospital',
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );

    final sidebar = find.byType(AdminWebSidebar);
    expect(tester.getSize(sidebar).width, 72);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(20, 100));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 72);

    await tester.tap(find.byTooltip('Expandir menú'));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 270);

    await mouse.moveTo(const Offset(500, 100));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 270);

    await tester.tap(find.byTooltip('Contraer menú'));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 72);
    await mouse.removePointer();
  });

  testWidgets('conserva la selección y las acciones del submenú', (
    tester,
  ) async {
    String? selected;
    String? action;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AdminWebSidebar(
                selectedSection: 'inicio',
                onSelectSection: (value) => selected = value,
                onAction: (value) => action = value,
                onSignOut: () {},
                userName: 'María',
                institutionName: 'Hospital',
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Expandir menú'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();
    expect(selected, 'inventario');

    await tester.tap(find.text('Catálogo y Stock de Lotes'));
    expect(action, 'Inventario');
  });
}
