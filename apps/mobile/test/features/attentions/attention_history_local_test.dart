import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/storage/app_database.dart';

void main() {
  test(
    'historial local filtra usuario e institución y pagina atenciones',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.patientsLocal)
          .insert(
            PatientsLocalCompanion.insert(
              id: 'p',
              institutionId: 'i',
              documentType: 'CC',
              documentNumber: '1',
              firstName: 'Ana',
              lastName: 'Paz',
              syncState: 'SYNCED',
              version: 0,
              updatedAt: 0,
            ),
          );
      final date = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < 22; i++) {
        await db.upsertAttentionLocal(
          AttentionsLocalCompanion.insert(
            id: 'a$i',
            institutionId: 'i',
            patientId: 'p',
            vaccinatorId: Value(i == 21 ? 'other' : 'nurse'),
            status: 'COMPLETED',
            version: 0,
            syncState: 'PENDING_SYNC',
            attentionDate: Value(date.millisecondsSinceEpoch ~/ 1000 + i),
            updatedAt: 0,
          ),
        );
      }
      Future<Map<String, dynamic>> page(int index) => db.attentionHistoryLocal(
        'i',
        'nurse',
        from: date,
        to: date.add(const Duration(days: 1)),
        page: index,
      );
      final first = await page(0);
      final second = await page(1);
      final third = await page(2);
      expect((first['items'] as List).length, 10);
      expect(first['hasNext'], true);
      expect((second['items'] as List).length, 10);
      expect(second['hasNext'], true);
      expect((third['items'] as List).length, 1);
      expect(third['hasNext'], false);
      expect((first['items'] as List).first['id'], 'a20');
      expect(
        (await db.attentionHistoryLocal(
          'different',
          'nurse',
          from: date,
          to: date.add(const Duration(days: 1)),
          page: 0,
        ))['items'],
        isEmpty,
      );
    },
  );
}
