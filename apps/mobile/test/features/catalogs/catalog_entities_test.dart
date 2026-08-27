import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/catalog_entities.dart';

void main() {
  test('parsea una vacuna versionada y calcula su rango', () {
    final vaccine = Vaccine.fromJson({
      'id': 'v-1',
      'name': 'BCG',
      'code': 'bcg',
      'category': 'PAI',
      'maxDoses': 1,
      'minAgeMonths': 0,
      'maxAgeMonths': 12,
      'active': true,
      'version': 4,
    });

    expect(vaccine.ageRange, '0-12 meses');
    expect(vaccine.version, 4);
  });

  test('acepta las dos convenciones de booleanos de la API', () {
    final option = VaccineOption.fromJson({
      'id': 'o-1',
      'vaccineId': 'v-1',
      'fieldType': 'dose',
      'value': '1',
      'displayName': 'Primera dosis',
      'sortOrder': 0,
      'isDefault': true,
      'isActive': true,
    });

    expect(option.isDefault, isTrue);
    expect(option.isActive, isTrue);
  });

  test('parsea la relacion institucional con su estado', () {
    final relation = InstitutionVaccine.fromJson({
      'id': 'rel-1',
      'institutionId': 'inst-1',
      'vaccineId': 'v-1',
      'name': 'BCG',
      'code': 'bcg',
      'category': 'PAI',
      'enabled': false,
      'version': 8,
    });

    expect(relation.enabled, isFalse);
    expect(relation.version, 8);
    expect(relation.vaccineId, 'v-1');
  });
}
