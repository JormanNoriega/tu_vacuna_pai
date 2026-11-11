import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'inventory_controller.dart';

/// Instantánea explícita; las entregas no son dosis aplicadas.
Future<bool> shareInventoryReport(
  InventoryController controller,
  String institution,
) async {
  await controller.load(institution, admin: true);
  if (controller.error != null) return false;
  await controller.loadMovements(institution);
  if (controller.error != null) return false;
  final rows = <List<Object?>>[
    ['Informe de inventario', 'Generado', DateTime.now().toIso8601String()],
    ['Institución', institution],
    ['Unidades', 'Frascos completos; entregas no equivalen a dosis aplicadas'],
    [],
    [
      'EXISTENCIAS ACTUALES',
      'Vacuna',
      'Lote',
      'Fabricante',
      'Vencimiento',
      'Dosis nominales por frasco',
      'Frascos en depósito',
    ],
    for (final l in controller.lots)
      [
        '',
        l['vaccineName'],
        l['lotNumber'],
        l['manufacturer'],
        l['expiresOn'],
        l['dosesPerVial'],
        l['availableVials'],
      ],
    [],
    ['MOVIMIENTOS', 'Fecha', 'Tipo', 'Vacuna', 'Lote', 'Frascos', 'Motivo'],
    for (final m in controller.movements)
      [
        '',
        m['occurredAt'],
        m['kind'],
        m['vaccineName'],
        m['lotNumber'],
        m['vialCount'],
        m['note'],
      ],
    [],
    [
      'ENTREGAS',
      'Fecha',
      'Vacuna',
      'Lote',
      'Vacunador ID',
      'Jornada',
      'Frascos',
      'Estado',
    ],
    for (final a in controller.assignments)
      [
        '',
        a['dispatchedAt'],
        a['vaccineName'],
        a['lotNumber'],
        a['vaccinatorId'],
        a['campaignName'],
        a['vialCount'],
        a['status'],
      ],
    [],
    ['JORNADAS', 'Nombre', 'Lugar', 'Inicio', 'Fin', 'Estado'],
    for (final c in controller.campaigns)
      ['', c['name'], c['location'], c['startsOn'], c['endsOn'], c['status']],
    [],
    [
      'DEVOLUCIONES Y NOVEDADES',
      'Vacuna',
      'Lote',
      'Frascos',
      'Estado',
      'Motivo',
    ],
    for (final e in controller.custodyEvents)
      [
        '',
        e['vaccineName'],
        e['lotNumber'],
        e['vialCount'],
        e['status'],
        e['reportNote'],
      ],
  ];
  final content = rows.map((row) => row.map(_cell).join(',')).join('\r\n');
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          Uint8List.fromList(utf8.encode('\ufeff$content')),
          mimeType: 'text/csv',
          name: 'inventario.csv',
        ),
      ],
      subject: 'Informe de inventario',
    ),
  );
  return true;
}

String _cell(Object? value) {
  var text = '${value ?? ''}';
  if (RegExp(r'^[\s]*[=+\-@\t\r]').hasMatch(text)) text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}
