import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tu_vacuna_pai/core/storage/app_database.dart';

/// Verificacion del cifrado real de la base local (ADR-003).
///
/// El binario nativo de SQLite se compila con SQLite3MultipleCiphers
/// (`hooks.user_defines.sqlite3.source = sqlite3mc` en pubspec.yaml). Sobre un
/// build sin cifrado, `PRAGMA key` era un no-op y estas aserciones fallarian,
/// por lo que actuan como guarda de regresion.
///
/// El ultimo test identifica explicitamente el motor: SQLite plano desconoce
/// `PRAGMA cipher` y `PRAGMA kdf_iter` (responden sin filas), mientras que
/// SQLite3MultipleCiphers expone el esquema activo y la derivacion de clave.
void main() {
  // Clave de 32 bytes en hexadecimal, como la genera AppDatabase.
  const key =
      'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
  const wrongKey =
      'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
  const secret = 'MEGA_SECRETO_XYZ';
  const secretKey = 'token_de_prueba';

  Future<AppDatabase> openEncrypted(String path) async {
    final connection = NativeDatabase(
      File(path),
      setup: (raw) {
        raw.execute("PRAGMA key = '$key'");
        raw.execute('PRAGMA cipher_memory_security = OFF');
      },
    );
    return AppDatabase(connection);
  }

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tu_vacuna_pai_crypto_');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // El archivo puede estar bloqueado por sqlite3; no falla el test.
    }
  });

  String dbPath() => '${tempDir.path}${Platform.pathSeparator}encrypted.db';

  test('la base creada con clave no deja el secreto en texto plano', () async {
    final db = await openEncrypted(dbPath());
    await db.setSyncMetadata(secretKey, secret);
    await db.close();

    final content = String.fromCharCodes(await File(dbPath()).readAsBytes());

    expect(content, isNot(contains(secret)));
    expect(content, isNot(contains(secretKey)));
  });

  test('no se puede leer la base con una clave incorrecta', () async {
    final db = await openEncrypted(dbPath());
    await db.setSyncMetadata(secretKey, secret);
    await db.close();

    final wrong = sqlite3.open(dbPath());
    wrong.execute("PRAGMA key = '$wrongKey'");
    expect(
      () => wrong.select('SELECT value FROM sync_metadata;'),
      throwsA(isA<SqliteException>()),
    );
    wrong.close();
  });

  test('con la clave correcta se lee el secreto guardado', () async {
    final db = await openEncrypted(dbPath());
    await db.setSyncMetadata(secretKey, secret);
    await db.close();

    final ok = sqlite3.open(dbPath());
    ok.execute("PRAGMA key = '$key'");
    ok.execute('PRAGMA cipher_memory_security = OFF');
    final rows = ok.select('SELECT value FROM sync_metadata;');

    expect(rows, hasLength(1));
    expect(rows.first.values.first, secret);
    ok.close();
  });

  test('el binario nativo es SQLite3MultipleCiphers (pragmas de cifrado)', () {
    final raw = sqlite3.open(dbPath());
    raw.execute("PRAGMA key = '$key'");
    raw.execute('PRAGMA cipher_memory_security = OFF');

    // Identificacion del motor: SQLite plano desconoce estos pragmas y
    // responde sin filas; SQLite3MultipleCiphers expone el esquema activo y
    // las rondas de derivacion de clave.
    final cipherRows = raw.select('PRAGMA cipher;');
    final kdfRows = raw.select('PRAGMA kdf_iter;');

    // Los pragmas de sqlite3mc devuelven TEXT aunque el valor sea numerico.
    final cipher =
        cipherRows.isEmpty ? null : cipherRows.first.values.first?.toString();
    final kdfRaw =
        kdfRows.isEmpty ? null : kdfRows.first.values.first?.toString();
    final kdfIter = kdfRaw == null ? null : int.tryParse(kdfRaw);

    stderr.writeln('PRAGMA cipher   = $cipher');
    stderr.writeln('PRAGMA kdf_iter = $kdfIter');

    expect(cipher?.toLowerCase(), 'chacha20');
    // Default de SQLite3MultipleCiphers para chacha20: PBKDF2-HMAC-SHA512 con
    // 64007 rondas. Si cambia, es una decision deliberada de configuracion.
    expect(kdfIter, 64007);

    raw.close();
  });
}
