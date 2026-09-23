import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Demo "en caliente" del cifrado de la base local (ADR-003), pensada para
/// clase e informe: crea una base cifrada en %TEMP%, inserta un dato
/// "confidencial" y muestra en pantalla:
///
///   1. El hexdump de los primeros bytes (sin cabecera "SQLite format 3").
///   2. Que el secreto NO aparece en texto plano dentro del archivo.
///   3. Que leer sin clave falla ("file is not a database").
///   4. Que leer con la clave correcta recupera el dato.
///
/// A diferencia de [database_encryption_test.dart], NO limpia el archivo al
/// terminar: queda en %TEMP%\tu_vacuna_pai_demo_cifrado\pacientes.db para
/// inspeccionarlo con editor hexadecimal o el comando sqlite3.
void main() {
  // Clave de 32 bytes en hexadecimal, como la genera AppDatabase.
  const key =
      'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
  const secret = 'PACIENTE_CONFIDENCIAL_12345';

  test('DEMO: el archivo de la base es ilegible sin la clave', () {
    final demoDir = Directory(
      '${Directory.systemTemp.path}'
      '${Platform.pathSeparator}tu_vacuna_pai_demo_cifrado',
    );
    if (demoDir.existsSync()) demoDir.deleteSync(recursive: true);
    demoDir.createSync(recursive: true);
    final dbPath = '${demoDir.path}${Platform.pathSeparator}pacientes.db';

    // 1. Crear y poblar la base cifrada (SQL 100% tradicional).
    final db = sqlite3.open(dbPath);
    db.execute("PRAGMA key = '$key'");
    db.execute('PRAGMA cipher_memory_security = OFF');
    db.execute('CREATE TABLE pacientes (id INTEGER PRIMARY KEY, nombre TEXT);');
    db.execute("INSERT INTO pacientes (nombre) VALUES ('$secret');");
    final rows = db.select('SELECT COUNT(*) FROM pacientes;');
    db.close();

    stderr.writeln('');
    stderr.writeln('=== DEMO CIFRADO: base local (SQLite3MultipleCiphers) ===');
    stderr.writeln('Archivo : $dbPath');
    stderr.writeln('Filas insertadas con clave: ${rows.first.values.first}');

    // 2. Hexdump de los primeros 64 bytes del archivo en disco.
    final bytes = File(dbPath).readAsBytesSync();
    final hex = bytes
        .take(64)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
    stderr.writeln('');
    stderr.writeln('Primeros 64 bytes del archivo:');
    stderr.writeln(hex);

    const plainHeader = 'SQLite format 3';
    final plainHeaderVisible =
        bytes.length >= plainHeader.length &&
            String.fromCharCodes(bytes.take(plainHeader.length)) ==
                plainHeader;
    stderr.writeln(
        'Cabecera "SQLite format 3" en texto plano: '
        '${plainHeaderVisible ? 'VISIBLE' : 'NO (cifrada)'}');
    expect(plainHeaderVisible, isFalse);
    expect(String.fromCharCodes(bytes), isNot(contains(secret)));

    // 3. Intento de lectura SIN clave: debe rechazar el archivo.
    final intruso = sqlite3.open(dbPath);
    expect(
      () => intruso.select('SELECT nombre FROM pacientes;'),
      throwsA(isA<SqliteException>()),
    );
    String intrusoError = '';
    try {
      intruso.select('SELECT nombre FROM pacientes;');
    } on SqliteException catch (e) {
      intrusoError = e.message;
    }
    intruso.close();
    stderr.writeln('Lectura sin clave: RECHAZADA ($intrusoError)');

    // 4. Lectura con la clave correcta: el dato vuelve intacto.
    final ok = sqlite3.open(dbPath);
    ok.execute("PRAGMA key = '$key'");
    ok.execute('PRAGMA cipher_memory_security = OFF');
    final nombre =
        ok.select('SELECT nombre FROM pacientes;').first.values.first;
    ok.close();
    stderr.writeln('Lectura con clave correcta: OK -> $nombre');
    expect(nombre, secret);
    stderr.writeln('=== FIN DEMO ===');
  });
}
