import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tu_vacuna_pai/core/storage/app_database.dart';

void main() {
  for (final version in [4, 5, 6]) {
    test(
      'migra desde V$version sin perder datos ni duplicar columnas',
      () async {
        final sqlite = sqlite3.openInMemory();
        sqlite.execute(
          'CREATE TABLE sync_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        sqlite.execute(
          "INSERT INTO sync_metadata VALUES ('marker', 'conservado')",
        );

        if (version >= 5) {
          sqlite.execute('''
          CREATE TABLE sync_outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation_id TEXT NOT NULL UNIQUE,
            command_type TEXT NOT NULL,
            aggregate_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            status TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            next_retry_at INTEGER,
            last_error TEXT,
            ${version >= 6 ? 'summary TEXT,' : ''}
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
          sqlite.execute('''
          CREATE TABLE attentions_local (
            id TEXT PRIMARY KEY,
            institution_id TEXT NOT NULL,
            patient_id TEXT NOT NULL,
            vaccinator_id TEXT,
            status TEXT NOT NULL,
            attention_date INTEGER,
            started_at INTEGER,
            completed_at INTEGER,
            observations TEXT,
            cancel_reason TEXT,
            version INTEGER NOT NULL,
            sync_state TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
          sqlite.execute('''
          INSERT INTO sync_outbox
            (operation_id, command_type, aggregate_id, payload, status, created_at, updated_at)
          VALUES ('op1', 'createPatient', 'p1', '{}', 'pending', 1, 1)
        ''');
          if (version >= 6) {
            sqlite.execute("UPDATE sync_outbox SET summary = 'pendiente'");
          }
          sqlite.execute('''
          INSERT INTO attentions_local
            (id, institution_id, patient_id, status, version, sync_state, updated_at)
          VALUES ('a1', 'i1', 'p1', 'open', 0, 'pending', 1)
        ''');
        }
        sqlite.execute('PRAGMA user_version = $version');

        final db = AppDatabase(NativeDatabase.opened(sqlite));
        addTearDown(db.close);

        final metadata = await db
            .customSelect('SELECT value FROM sync_metadata')
            .getSingle();
        expect(metadata.read<String>('value'), 'conservado');
        final outbox = await db
            .customSelect('SELECT operation_id, summary FROM sync_outbox')
            .get();
        final attentions = await db
            .customSelect(
              'SELECT id, latitude, longitude FROM attentions_local',
            )
            .get();
        if (version >= 5) {
          expect(outbox.single.read<String>('operation_id'), 'op1');
          expect(
            outbox.single.readNullable<String>('summary'),
            version == 6 ? 'pendiente' : null,
          );
          expect(attentions.single.read<String>('id'), 'a1');
          expect(attentions.single.readNullable<double>('latitude'), isNull);
          expect(attentions.single.readNullable<double>('longitude'), isNull);
        } else {
          expect(outbox, isEmpty);
          expect(attentions, isEmpty);
        }
        final schemaVersion = await db
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(schemaVersion.read<int>('user_version'), 7);
      },
    );
  }
}
