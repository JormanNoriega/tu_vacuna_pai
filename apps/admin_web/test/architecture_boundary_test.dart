@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la web no depende de la app móvil ni del motor offline', () {
    final config = jsonDecode(
      File('.dart_tool/package_config.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final packages = (config['packages'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final names = packages.map((package) => package['name']).toSet();

    expect(
      names.intersection({
        'tu_vacuna_pai',
        'drift',
        'drift_flutter',
        'sqlite3',
      }),
      isEmpty,
    );
    for (final package in packages) {
      final root = Uri.parse(package['rootUri'] as String);
      final resolved = File('.dart_tool/package_config.json').absolute.uri
          .resolveUri(root)
          .normalizePath()
          .toString()
          .replaceAll('\\', '/');
      expect(resolved.contains('/apps/mobile/'), isFalse, reason: resolved);
    }
  });
}
